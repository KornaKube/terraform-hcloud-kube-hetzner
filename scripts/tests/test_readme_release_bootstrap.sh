#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
require_pinned=false
case "${1:-}" in
  "") ;;
  --require-pinned) require_pinned=true ;;
  *) printf 'usage: %s [--require-pinned]\n' "$0" >&2; exit 2 ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/runtime"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

bootstrap="$tmp/bootstrap.sh"
awk '
  /^# BEGIN_KH_VERIFIED_BOOTSTRAP$/ { capture=1; next }
  /^# END_KH_VERIFIED_BOOTSTRAP$/ { capture=0 }
  capture { print }
' "$repo_root/README.md" > "$bootstrap"
[[ -s "$bootstrap" ]] || fail "README bootstrap block was not found"

if rg -n 'releases/latest|git ls-remote|raw\.githubusercontent\.com|/raw/|KH_RELEASE' "$bootstrap"; then
  fail "verified bootstrap still resolves or downloads a moving/raw entrypoint"
fi
[[ "$(grep -c '^[[:space:]]*curl -fsS ' "$bootstrap")" == 1 ]] \
  || fail "bootstrap must make exactly one archive request"
grep -Fq "https://codeload.github.com/mysticaltech/terraform-hcloud-kube-hetzner/tar.gz/\$kh_commit" "$bootstrap" \
  || fail "bootstrap must use the canonical commit-addressed Codeload archive"
grep -Fq -- "--max-redirs 0" "$bootstrap" || fail "archive download must reject redirects"
grep -Fq "KH_SOURCE_DIRECTORY=\"\$kh_source\"" "$bootstrap" \
  || fail "bootstrap must override inherited source-directory state"
grep -Fq "KH_SOURCE_ARCHIVE_SHA256=\"\$kh_archive_sha256\"" "$bootstrap" \
  || fail "create.sh must receive the reviewed archive digest"

pinned_commit="$(sed -n 's/^  kh_commit="\([^"]*\)"$/\1/p' "$bootstrap")"
pinned_archive_sha256="$(sed -n 's/^  kh_archive_sha256="\([^"]*\)"$/\1/p' "$bootstrap")"
pinned_manifest_sha256="$(sed -n 's/^  kh_manifest_sha256="\([^"]*\)"$/\1/p' "$bootstrap")"
[[ -n "$pinned_commit" && -n "$pinned_archive_sha256" && -n "$pinned_manifest_sha256" ]] \
  || fail "bootstrap pins could not be parsed"

fixture_commit="1111111111111111111111111111111111111111"
fixture_root="$tmp/archive/terraform-hcloud-kube-hetzner-$fixture_commit"
mkdir -p "$fixture_root/scripts" "$fixture_root/packer-template"
printf '%s\n' 'fixture security manifest' > "$fixture_root/packer-template/security-bundle.sha256"
cat > "$fixture_root/scripts/create.sh" <<'FAKE_CREATE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$KH_SOURCE_DIRECTORY" > "$BOOTSTRAP_CAPTURE_DIR/source-directory"
printf '%s\n' "$KH_SOURCE_COMMIT" > "$BOOTSTRAP_CAPTURE_DIR/commit"
printf '%s\n' "$KH_SOURCE_ARCHIVE_SHA256" > "$BOOTSTRAP_CAPTURE_DIR/archive-digest"
printf '%s\n' "$KH_PACKER_BUNDLE_MANIFEST_SHA256" > "$BOOTSTRAP_CAPTURE_DIR/manifest-digest"
touch "$BOOTSTRAP_CAPTURE_DIR/executed"
FAKE_CREATE
chmod 700 "$fixture_root/scripts/create.sh"

fixture_archive="$tmp/fixture.tar.gz"
tar -czf "$fixture_archive" -C "$tmp/archive" "$(basename "$fixture_root")"
fixture_archive_sha256="$(sha256_file "$fixture_archive")"
fixture_manifest_sha256="$(sha256_file "$fixture_root/packer-template/security-bundle.sha256")"

patch_bootstrap() {
  local source="$1"
  local destination="$2"
  local commit="$3"
  local archive_sha256="$4"
  local manifest_sha256="$5"
  awk \
    -v commit="$commit" \
    -v archive_sha256="$archive_sha256" \
    -v manifest_sha256="$manifest_sha256" '
      /^  kh_commit=/ { print "  kh_commit=\"" commit "\""; next }
      /^  kh_archive_sha256=/ { print "  kh_archive_sha256=\"" archive_sha256 "\""; next }
      /^  kh_manifest_sha256=/ { print "  kh_manifest_sha256=\"" manifest_sha256 "\""; next }
      { print }
    ' "$source" > "$destination"
}

cat > "$tmp/bin/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
set -euo pipefail
output=""
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    https://*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done
[[ -n "$output" && -n "$url" ]]
printf '%s\n' "$url" >> "$BOOTSTRAP_URL_LOG"
cp "$BOOTSTRAP_ARCHIVE_SOURCE" "$output"
FAKE_CURL
chmod 700 "$tmp/bin/curl"

fixture_bootstrap="$tmp/fixture-bootstrap.sh"
patch_bootstrap "$bootstrap" "$fixture_bootstrap" \
  "$fixture_commit" "$fixture_archive_sha256" "$fixture_manifest_sha256"

capture="$tmp/capture"
mkdir "$capture"
env \
  PATH="$tmp/bin:$PATH" \
  TMPDIR="$tmp/runtime" \
  KH_SOURCE_DIRECTORY="$tmp/attacker-controlled-source" \
  BOOTSTRAP_ARCHIVE_SOURCE="$fixture_archive" \
  BOOTSTRAP_URL_LOG="$tmp/urls" \
  BOOTSTRAP_CAPTURE_DIR="$capture" \
  sh "$fixture_bootstrap"

[[ -f "$capture/executed" ]] || fail "verified extracted entrypoint did not execute"
[[ "$(cat "$capture/commit")" == "$fixture_commit" ]] || fail "entrypoint received the wrong commit"
[[ "$(cat "$capture/archive-digest")" == "$fixture_archive_sha256" ]] || fail "entrypoint received the wrong archive digest"
[[ "$(cat "$capture/manifest-digest")" == "$fixture_manifest_sha256" ]] || fail "entrypoint received the wrong manifest digest"
[[ "$(cat "$capture/source-directory")" != "$tmp/attacker-controlled-source" ]] \
  || fail "inherited source directory bypassed verified extraction"
case "$(cat "$capture/source-directory")" in
  */source) ;;
  *) fail "entrypoint did not execute from the verified temporary extraction" ;;
esac
[[ "$(wc -l < "$tmp/urls" | tr -d ' ')" == 1 ]] || fail "fixture bootstrap made more than one request"
[[ "$(cat "$tmp/urls")" == "https://codeload.github.com/mysticaltech/terraform-hcloud-kube-hetzner/tar.gz/$fixture_commit" ]] \
  || fail "fixture bootstrap escaped the pinned Codeload URL"

tampered_archive="$tmp/tampered.tar.gz"
cp "$fixture_archive" "$tampered_archive"
printf '%s' tampered >> "$tampered_archive"
tampered_capture="$tmp/tampered-capture"
mkdir "$tampered_capture"
if env \
  PATH="$tmp/bin:$PATH" \
  TMPDIR="$tmp/runtime" \
  BOOTSTRAP_ARCHIVE_SOURCE="$tampered_archive" \
  BOOTSTRAP_URL_LOG="$tmp/tampered-urls" \
  BOOTSTRAP_CAPTURE_DIR="$tampered_capture" \
  sh "$fixture_bootstrap" >/dev/null 2>&1; then
  fail "tampered archive was accepted"
fi
[[ ! -e "$tampered_capture/executed" ]] || fail "tampered archive executed release code"

wrong_manifest_bootstrap="$tmp/wrong-manifest-bootstrap.sh"
patch_bootstrap "$bootstrap" "$wrong_manifest_bootstrap" \
  "$fixture_commit" "$fixture_archive_sha256" \
  "0000000000000000000000000000000000000000000000000000000000000000"
wrong_manifest_capture="$tmp/wrong-manifest-capture"
mkdir "$wrong_manifest_capture"
if env \
  PATH="$tmp/bin:$PATH" \
  TMPDIR="$tmp/runtime" \
  BOOTSTRAP_ARCHIVE_SOURCE="$fixture_archive" \
  BOOTSTRAP_URL_LOG="$tmp/wrong-manifest-urls" \
  BOOTSTRAP_CAPTURE_DIR="$wrong_manifest_capture" \
  sh "$wrong_manifest_bootstrap" >/dev/null 2>&1; then
  fail "wrong manifest digest was accepted"
fi
[[ ! -e "$wrong_manifest_capture/executed" ]] || fail "wrong manifest digest executed release code"

missing_archive_bootstrap="$tmp/missing-archive-bootstrap.sh"
patch_bootstrap "$bootstrap" "$missing_archive_bootstrap" \
  "$fixture_commit" "" "$fixture_manifest_sha256"
missing_archive_capture="$tmp/missing-archive-capture"
mkdir "$missing_archive_capture"
if env \
  PATH="$tmp/bin:$PATH" \
  TMPDIR="$tmp/runtime" \
  BOOTSTRAP_ARCHIVE_SOURCE="$fixture_archive" \
  BOOTSTRAP_URL_LOG="$tmp/missing-archive-urls" \
  BOOTSTRAP_CAPTURE_DIR="$missing_archive_capture" \
  sh "$missing_archive_bootstrap" >/dev/null 2>&1; then
  fail "missing archive digest was accepted"
fi
[[ ! -s "$tmp/missing-archive-urls" ]] || fail "missing archive digest reached the network"
[[ ! -e "$missing_archive_capture/executed" ]] || fail "missing archive digest executed release code"

if $require_pinned; then
  [[ "$pinned_commit" =~ ^[0-9a-f]{40}$ ]] || fail "release bootstrap commit is not pinned"
  [[ "$pinned_archive_sha256" =~ ^[0-9a-f]{64}$ ]] || fail "release bootstrap archive digest is not pinned"
  [[ "$pinned_manifest_sha256" =~ ^[0-9a-f]{64}$ ]] || fail "release bootstrap manifest digest is not pinned"

  mkdir -p "$tmp/actual-home" "$tmp/actual-projects"
  env -i \
    PATH="$PATH" \
    HOME="$tmp/actual-home" \
    TMPDIR="$tmp/runtime" \
    folder_name=generated \
    folder_path="$tmp/actual-projects" \
    create_snapshots=none \
    KH_SOURCE_DIRECTORY="$tmp/attacker-controlled-source" \
    sh "$bootstrap"
  [[ -f "$tmp/actual-projects/generated/kube.tf" ]] \
    || fail "real pinned bootstrap did not publish kube.tf"
  [[ -f "$tmp/actual-projects/generated/packer/security-bundle.sha256" ]] \
    || fail "real pinned bootstrap did not publish the verified Packer bundle"
fi

printf 'PASS: README bootstrap verifies one immutable archive, rejects tampering, and cannot inherit an unverified source.\n'

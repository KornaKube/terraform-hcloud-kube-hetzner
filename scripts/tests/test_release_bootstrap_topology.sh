#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
checker_source="$repo_root/scripts/check-release-bootstrap-topology.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/repository"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_rejected() {
  local ref="$1"
  local label="$2"
  if "$fixture/scripts/check-release-bootstrap-topology.sh" "$ref" >"$tmp/$label.log" 2>&1; then
    fail "$label was accepted"
  fi
}

pin_readme() {
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

mkdir -p "$fixture/scripts" "$fixture/packer-template"
cp "$checker_source" "$fixture/scripts/check-release-bootstrap-topology.sh"
chmod 700 "$fixture/scripts/check-release-bootstrap-topology.sh"
printf '%s\n' 'base' > "$fixture/BASE"
git -C "$fixture" init -q
git -C "$fixture" config user.name 'Release Contract Test'
git -C "$fixture" config user.email 'release-contract@example.invalid'
git -C "$fixture" add .
git -C "$fixture" commit -q -m 'base commit'
base_commit="$(git -C "$fixture" rev-parse HEAD)"
cat > "$fixture/README.md" <<'README'
# Fixture

  kh_commit="__KH_SOURCE_COMMIT__"
  kh_archive_sha256="__KH_SOURCE_ARCHIVE_SHA256__"
  kh_manifest_sha256="__KH_PACKER_BUNDLE_MANIFEST_SHA256__"
README
printf '%s\n' 'fixture security manifest' > "$fixture/packer-template/security-bundle.sha256"
git -C "$fixture" add .
git -C "$fixture" commit -q -m 'functional commit'
functional_commit="$(git -C "$fixture" rev-parse HEAD)"
manifest_sha256="$(shasum -a 256 "$fixture/packer-template/security-bundle.sha256" | awk '{ print $1 }')"
archive_sha256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

pin_readme "$fixture/README.md" "$tmp/pinned-readme" \
  "$functional_commit" "$archive_sha256" "$manifest_sha256"
mv "$tmp/pinned-readme" "$fixture/README.md"
git -C "$fixture" add README.md
git -C "$fixture" commit -q -m 'pin release bootstrap'
safe_release="$(git -C "$fixture" rev-parse HEAD)"
"$fixture/scripts/check-release-bootstrap-topology.sh" "$safe_release" >/dev/null \
  || fail "safe A/B topology was rejected"
if "$fixture/scripts/check-release-bootstrap-topology.sh" --require-merge "$safe_release" >/dev/null 2>&1; then
  fail "direct pin commit was accepted as a protected merge"
fi

git -C "$fixture" checkout -q -b safe-merge "$base_commit"
git -C "$fixture" merge -q --no-ff --no-edit "$safe_release"
safe_merge="$(git -C "$fixture" rev-parse HEAD)"
"$fixture/scripts/check-release-bootstrap-topology.sh" --require-merge "$safe_merge" >/dev/null \
  || fail "safe protected merge topology was rejected"

# Subsequent releases retain the previous valid pins in functional commit A;
# only the release-preparation commit B replaces those three values.
git -C "$fixture" checkout -q -b retained-pins "$safe_release"
printf '%s\n' 'next release functionality' > "$fixture/runtime.tf"
git -C "$fixture" add runtime.tf
git -C "$fixture" commit -q -m 'next functional commit with previous pins'
retained_pins_functional="$(git -C "$fixture" rev-parse HEAD)"
retained_manifest_sha256="$(shasum -a 256 "$fixture/packer-template/security-bundle.sha256" | awk '{ print $1 }')"
pin_readme "$fixture/README.md" "$tmp/retained-pins-readme" \
  "$retained_pins_functional" "$archive_sha256" "$retained_manifest_sha256"
mv "$tmp/retained-pins-readme" "$fixture/README.md"
git -C "$fixture" add README.md
git -C "$fixture" commit -q -m 'repin next release bootstrap'
"$fixture/scripts/check-release-bootstrap-topology.sh" HEAD >/dev/null \
  || fail "functional commit retaining previous release pins was rejected"

git -C "$fixture" checkout -q -b functional-drift "$safe_release"
printf '%s\n' 'unverified functional change' > "$fixture/runtime.tf"
git -C "$fixture" add runtime.tf
git -C "$fixture" commit -q -m 'change runtime after canary'
expect_rejected HEAD functional-drift

git -C "$fixture" checkout -q -b modify-revert "$functional_commit"
printf '%s\n' 'temporary unverified runtime' > "$fixture/runtime.tf"
git -C "$fixture" add runtime.tf
git -C "$fixture" commit -q -m 'temporarily change runtime'
git -C "$fixture" rm -q runtime.tf
git -C "$fixture" commit -q -m 'revert runtime bytes'
pin_readme "$fixture/README.md" "$tmp/reverted-pinned-readme" \
  "$functional_commit" "$archive_sha256" "$manifest_sha256"
mv "$tmp/reverted-pinned-readme" "$fixture/README.md"
git -C "$fixture" add README.md
git -C "$fixture" commit -q -m 'pin after hidden modify-revert history'
expect_rejected HEAD modify-revert-history

git -C "$fixture" checkout -q -b readme-mode "$functional_commit"
pin_readme "$fixture/README.md" "$tmp/mode-pinned-readme" \
  "$functional_commit" "$archive_sha256" "$manifest_sha256"
mv "$tmp/mode-pinned-readme" "$fixture/README.md"
chmod 755 "$fixture/README.md"
git -C "$fixture" add README.md
git -C "$fixture" commit -q -m 'pin with README mode drift'
expect_rejected HEAD readme-mode-drift

git -C "$fixture" checkout -q -b extra-commit "$safe_release"
git -C "$fixture" commit -q --allow-empty -m 'extra post-pin commit'
expect_rejected HEAD extra-post-pin-commit

git -C "$fixture" checkout -q -b readme-drift "$safe_release"
printf '%s\n' 'unreviewed prose' >> "$fixture/README.md"
git -C "$fixture" add README.md
git -C "$fixture" commit -q -m 'change README outside pins'
expect_rejected HEAD readme-drift

git -C "$fixture" checkout -q -b wrong-manifest "$safe_release"
sed 's/^  kh_manifest_sha256=.*/  kh_manifest_sha256="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"/' \
  "$fixture/README.md" > "$tmp/wrong-manifest-readme"
mv "$tmp/wrong-manifest-readme" "$fixture/README.md"
git -C "$fixture" add README.md
git -C "$fixture" commit -q -m 'pin wrong manifest'
expect_rejected HEAD wrong-manifest

unrelated_base="$(printf '%s\n' 'unrelated base' | git -C "$fixture" commit-tree "${base_commit}^{tree}")"
git -C "$fixture" checkout -q -b unrelated-merge "$unrelated_base"
git -C "$fixture" merge -q --allow-unrelated-histories --no-ff --no-edit "$safe_release"
expect_rejected HEAD unrelated-merge-parent

git -C "$fixture" checkout -q --orphan unrelated-release
git -C "$fixture" rm -q -rf .
mkdir -p "$fixture/scripts" "$fixture/packer-template"
cp "$checker_source" "$fixture/scripts/check-release-bootstrap-topology.sh"
chmod 700 "$fixture/scripts/check-release-bootstrap-topology.sh"
git -C "$fixture" show "$safe_release:README.md" > "$fixture/README.md"
git -C "$fixture" show "$functional_commit:packer-template/security-bundle.sha256" \
  > "$fixture/packer-template/security-bundle.sha256"
git -C "$fixture" add .
git -C "$fixture" commit -q -m 'unrelated tree with copied pins'
expect_rejected HEAD unrelated-history

printf 'PASS: release topology enforces exact A/B history, README mode, and the protected merge-parent contract.\n'

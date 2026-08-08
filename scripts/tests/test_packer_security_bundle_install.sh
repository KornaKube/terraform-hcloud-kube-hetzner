#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_root="$repo_root/packer-template"
installer="$source_root/scripts/install-packer-security-bundle.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

manifest_sha256="$(sha256_file "$source_root/security-bundle.sha256")"
valid_parent="$tmp/valid-project"
valid_target="$valid_parent/packer"
mkdir -p "$valid_parent"
printf '%s\n' 'preserve-user-kube-config' > "$valid_parent/kube.tf"
bash "$installer" "$source_root" "$valid_target" "$manifest_sha256" >/dev/null
bash "$installer" "$source_root" "$valid_target" "$manifest_sha256" >/dev/null
[[ -L "$valid_target" ]] \
  || { echo "FAIL: installer did not atomically publish one bundle link" >&2; exit 1; }
grep -Fxq 'preserve-user-kube-config' "$valid_parent/kube.tf" \
  || { echo "FAIL: bundle transaction modified user kube.tf" >&2; exit 1; }

while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    '' | \#*) continue ;;
  esac
  digest="${line%%[[:space:]]*}"
  relative_path="${line#"$digest"}"
  relative_path="${relative_path#"${relative_path%%[![:space:]]*}"}"
  [[ -f "$valid_target/$relative_path" ]] \
    || { echo "FAIL: installer omitted $relative_path" >&2; exit 1; }
  [[ "$(sha256_file "$valid_target/$relative_path")" == "$digest" ]] \
    || { echo "FAIL: installer changed $relative_path" >&2; exit 1; }
done < "$source_root/security-bundle.sha256"
cmp "$source_root/security-bundle.sha256" \
  "$valid_target/security-bundle.sha256" >/dev/null

# Mutating the caller-owned manifest immediately after its first digest check
# must not affect parsing or the bytes published into the trusted generation.
race_source="$tmp/race-source"
race_parent="$tmp/race-project"
race_target="$race_parent/packer"
fake_bin="$tmp/fake-bin"
cp -R "$source_root" "$race_source"
cp "$race_source/security-bundle.sha256" "$tmp/pristine-manifest"
mkdir -p "$race_parent" "$fake_bin"
real_sha256_tool="$(command -v sha256sum || command -v shasum)"
cat > "$fake_bin/sha256sum" <<'FAKE_SHA256'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$(basename "$REAL_SHA256_TOOL")" == sha256sum ]]; then
  "$REAL_SHA256_TOOL" "$@"
else
  "$REAL_SHA256_TOOL" -a 256 "$@"
fi
if [[ ! -e "$MUTATION_MARKER" && "${1##*/}" == security-bundle.sha256 ]]; then
  : > "$MUTATION_MARKER"
  printf '\n# mutated after digest verification\n' >> "$SOURCE_MANIFEST_TO_MUTATE"
fi
FAKE_SHA256
chmod 700 "$fake_bin/sha256sum"
env \
  PATH="$fake_bin:$PATH" \
  REAL_SHA256_TOOL="$real_sha256_tool" \
  MUTATION_MARKER="$tmp/manifest-mutated" \
  SOURCE_MANIFEST_TO_MUTATE="$race_source/security-bundle.sha256" \
  bash "$installer" "$race_source" "$race_target" "$manifest_sha256" >/dev/null
[[ -e "$tmp/manifest-mutated" ]] \
  || { echo "FAIL: manifest mutation fixture did not run" >&2; exit 1; }
cmp "$tmp/pristine-manifest" "$race_target/security-bundle.sha256" >/dev/null \
  || { echo "FAIL: published bundle did not use the verified manifest snapshot" >&2; exit 1; }

wrong_digest_target="$tmp/wrong-digest"
if bash "$installer" "$source_root" "$wrong_digest_target" \
  0000000000000000000000000000000000000000000000000000000000000000 \
  >"$tmp/wrong-digest.log" 2>&1; then
  echo "FAIL: installer accepted the wrong reviewed manifest digest" >&2
  exit 1
fi
[[ ! -e "$wrong_digest_target/hcloud-leapmicro-snapshots.pkr.hcl" ]] \
  || { echo "FAIL: wrong manifest digest installed bundle files" >&2; exit 1; }

tampered_source="$tmp/tampered-source"
cp -R "$source_root" "$tampered_source"
printf '\n# tampered\n' >> "$tampered_source/hcloud-leapmicro-snapshots.pkr.hcl"
if bash "$installer" "$tampered_source" "$tmp/tampered-target" "$manifest_sha256" \
  >"$tmp/tampered.log" 2>&1; then
  echo "FAIL: installer accepted a source file that disagrees with the manifest" >&2
  exit 1
fi
[[ ! -e "$tmp/tampered-target/hcloud-leapmicro-snapshots.pkr.hcl" ]] \
  || { echo "FAIL: tampered source installed bundle files" >&2; exit 1; }

partial_parent="$tmp/partial"
partial_target="$partial_parent/packer"
mkdir -p "$partial_parent/keys"
cp "$source_root/keys/opensuse-project-signing-key.asc" "$partial_parent/keys/"
if bash "$installer" "$source_root" "$partial_target" "$manifest_sha256" \
  >"$tmp/partial.log" 2>&1; then
  echo "FAIL: installer accepted a partial pre-manifest bundle" >&2
  exit 1
fi
cmp "$source_root/keys/opensuse-project-signing-key.asc" \
  "$partial_parent/keys/opensuse-project-signing-key.asc" >/dev/null
[[ ! -e "$partial_target" && ! -L "$partial_target" ]] \
  || { echo "FAIL: partial old bundle gained an atomic bundle link" >&2; exit 1; }

printf '\n# local edit\n' >> "$valid_target/scripts/verify-rancher-rpm.sh"
if bash "$installer" "$source_root" "$valid_target" "$manifest_sha256" \
  >"$tmp/modified.log" 2>&1; then
  echo "FAIL: installer accepted a modified existing bundle" >&2
  exit 1
fi

echo "PASS: Packer security bundle install is manifest-bound, idempotent, and fail-closed."

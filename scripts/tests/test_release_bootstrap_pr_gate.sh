#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/check-release-bootstrap-pr-gate.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail_test() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_state() {
  local fixture="$1"
  local expected="$2"
  local label="$3"
  local actual
  actual="$(classify_release_bootstrap_readme "$fixture")" \
    || fail_test "$label was rejected"
  [[ "$actual" == "$expected" ]] || fail_test "$label was classified as $actual"
}

expect_rejected() {
  local fixture="$1"
  local label="$2"
  if classify_release_bootstrap_readme "$fixture" >/dev/null 2>&1; then
    fail_test "$label was accepted"
  fi
}

cat > "$tmp/placeholders" <<'EOF'
# BEGIN_KH_VERIFIED_BOOTSTRAP
  kh_commit="__KH_SOURCE_COMMIT__"
  kh_archive_sha256="__KH_SOURCE_ARCHIVE_SHA256__"
  kh_manifest_sha256="__KH_PACKER_BUNDLE_MANIFEST_SHA256__"
# END_KH_VERIFIED_BOOTSTRAP
EOF
expect_state "$tmp/placeholders" placeholders "exact placeholder state"

cat > "$tmp/pinned" <<'EOF'
# BEGIN_KH_VERIFIED_BOOTSTRAP
  kh_commit="1111111111111111111111111111111111111111"
  kh_archive_sha256="2222222222222222222222222222222222222222222222222222222222222222"
  kh_manifest_sha256="3333333333333333333333333333333333333333333333333333333333333333"
# END_KH_VERIFIED_BOOTSTRAP
EOF
expect_state "$tmp/pinned" pinned "exact pinned state"

cp "$tmp/pinned" "$tmp/marker-in-prose"
printf '%s\n' '<!-- __KH_SOURCE_COMMIT__ -->' >> "$tmp/marker-in-prose"
expect_state "$tmp/marker-in-prose" pinned "pinned state with marker in prose"

sed 's/^  kh_commit=.*/  kh_commit="__KH_SOURCE_COMMIT__"/' "$tmp/pinned" > "$tmp/partial"
expect_rejected "$tmp/partial" "partial pin state"

cp "$tmp/pinned" "$tmp/duplicate"
awk '
  /^# END_KH_VERIFIED_BOOTSTRAP$/ { print "  kh_commit=\"4444444444444444444444444444444444444444\"" }
  { print }
' "$tmp/pinned" > "$tmp/duplicate-within-block"
mv "$tmp/duplicate-within-block" "$tmp/duplicate"
expect_rejected "$tmp/duplicate" "duplicate pin assignment"

for prefix in '' ' ' '   ' $'\t'; do
  awk -v extra="${prefix}kh_commit=\"4444444444444444444444444444444444444444\"" '
    /^# END_KH_VERIFIED_BOOTSTRAP$/ { print extra }
    { print }
  ' "$tmp/placeholders" > "$tmp/noncanonical"
  expect_rejected "$tmp/noncanonical" "noncanonical effective pin assignment"
done

printf 'PASS: PR bootstrap classification is block-scoped and rejects marker, partial, duplicate, and noncanonical-assignment bypasses.\n'

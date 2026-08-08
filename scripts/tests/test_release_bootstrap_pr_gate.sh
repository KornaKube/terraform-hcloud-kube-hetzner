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

repo="$tmp/repo"
mkdir "$repo"
git -C "$repo" init --quiet
git -C "$repo" config user.name 'Release Fixture'
git -C "$repo" config user.email 'release-fixture@example.invalid'
cp "$tmp/pinned" "$repo/README.md"
printf 'base\n' > "$repo/runtime.tf"
git -C "$repo" add README.md runtime.tf
git -C "$repo" commit --quiet -m base
base_sha="$(git -C "$repo" rev-parse HEAD)"

mkdir -p "$repo/scripts/tests"
cp "$repo_root/scripts/check-release-bootstrap-pr-gate.sh" "$repo/scripts/"
cat > "$repo/scripts/check-release-bootstrap-topology.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'topology:%s\n' "${1-}" >> "$DISPATCH_LOG"
EOF
cat > "$repo/scripts/tests/test_readme_release_bootstrap.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1-}" in
  --require-pinned)
    printf 'bootstrap:--require-pinned\n' >> "$DISPATCH_LOG"
    ;;
  '')
    printf 'bootstrap:fixture\n' >> "$DISPATCH_LOG"
    ;;
  *)
    exit 1
    ;;
esac
EOF
chmod +x \
  "$repo/scripts/check-release-bootstrap-pr-gate.sh" \
  "$repo/scripts/check-release-bootstrap-topology.sh" \
  "$repo/scripts/tests/test_readme_release_bootstrap.sh"
dispatch_log="$repo/dispatch.log"

run_executable_gate() {
  local base_ref="$1"
  (
    cd "$repo"
    KH_RELEASE_BASE_REF="$base_ref" DISPATCH_LOG="$dispatch_log" \
      scripts/check-release-bootstrap-pr-gate.sh
  )
}

printf 'development\n' >> "$repo/runtime.tf"
printf '\nDocumentation outside the bootstrap block.\n' >> "$repo/README.md"
git -C "$repo" commit --quiet -am development
awk '
  /^# END_KH_VERIFIED_BOOTSTRAP$/ { print "  printf bootstrap-body-v2\\n" }
  { print }
' "$repo/README.md" > "$repo/README.next"
mv "$repo/README.next" "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit --quiet -m 'change bootstrap body while retaining pins'
functional_sha="$(git -C "$repo" rev-parse HEAD)"
(
  cd "$repo"
  release_bootstrap_pins_match_base "$base_sha"
) || fail_test "unchanged pinned bootstrap was rejected on a development commit"
: > "$dispatch_log"
run_executable_gate "$base_sha" >/dev/null \
  || fail_test "functional bootstrap change with retained pins failed the executable gate"
[[ "$(cat "$dispatch_log")" == 'bootstrap:--require-pinned' ]] \
  || fail_test "retained pins did not run only the real pinned-bootstrap path"

sed -i.bak "s/kh_commit=\"1111111111111111111111111111111111111111/kh_commit=\"$functional_sha/" "$repo/README.md"
rm "$repo/README.md.bak"
git -C "$repo" commit --quiet -am repin
if (cd "$repo" && release_bootstrap_pins_match_base "$base_sha"); then
  fail_test "changed bootstrap pins bypassed strict release topology"
fi
: > "$dispatch_log"
run_executable_gate "$base_sha" >/dev/null \
  || fail_test "repinned bootstrap failed the executable gate"
[[ "$(cat "$dispatch_log")" == $'topology:HEAD\nbootstrap:--require-pinned' ]] \
  || fail_test "repinned bootstrap did not run topology before the pinned-bootstrap path"

valid_pin_branch="$(git -C "$repo" branch --show-current)"
git -C "$repo" switch --quiet --create hidden-placeholder "$functional_sha"
cp "$tmp/placeholders" "$repo/README.md"
git -C "$repo" commit --quiet -am 'hidden functional pin regression'
hidden_functional_sha="$(git -C "$repo" rev-parse HEAD)"
sed \
  -e "s/__KH_SOURCE_COMMIT__/$hidden_functional_sha/" \
  -e 's/__KH_SOURCE_ARCHIVE_SHA256__/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/' \
  -e 's/__KH_PACKER_BUNDLE_MANIFEST_SHA256__/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/' \
  "$repo/README.md" > "$repo/README.next"
mv "$repo/README.next" "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit --quiet -m 'pin hidden functional regression'
: > "$dispatch_log"
if run_executable_gate "$base_sha" >/dev/null 2>&1; then
  fail_test "hidden pinned-to-placeholder functional commit was accepted"
fi
[[ ! -s "$dispatch_log" ]] \
  || fail_test "hidden functional pin regression reached a release verification dependency"
git -C "$repo" switch --quiet "$valid_pin_branch"

cp "$tmp/placeholders" "$repo/README.md"
git -C "$repo" commit --quiet -am 'revert pins to placeholders'
: > "$dispatch_log"
if run_executable_gate "$base_sha" >/dev/null 2>&1; then
  fail_test "pinned base was allowed to regress to placeholders"
fi
[[ ! -s "$dispatch_log" ]] \
  || fail_test "pinned-to-placeholder regression reached a release verification dependency"

placeholder_base_sha="$(git -C "$repo" rev-parse HEAD)"
printf 'placeholder development\n' >> "$repo/runtime.tf"
git -C "$repo" commit --quiet -am 'develop from placeholder base'
: > "$dispatch_log"
run_executable_gate "$placeholder_base_sha" >/dev/null \
  || fail_test "unchanged placeholder base failed the executable gate"
[[ "$(cat "$dispatch_log")" == 'bootstrap:fixture' ]] \
  || fail_test "unchanged placeholders did not run the bootstrap fixture"

: > "$dispatch_log"
if run_executable_gate missing-ref >/dev/null 2>&1; then
  fail_test "invalid trusted base ref was accepted"
fi
[[ ! -s "$dispatch_log" ]] \
  || fail_test "invalid base ref reached a release verification dependency"

current_branch="$(git -C "$repo" branch --show-current)"
git -C "$repo" switch --quiet --create unrelated "$base_sha"
printf 'unrelated\n' > "$repo/unrelated"
git -C "$repo" add unrelated
git -C "$repo" commit --quiet -m unrelated
unrelated_sha="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" switch --quiet "$current_branch"
: > "$dispatch_log"
if run_executable_gate "$unrelated_sha" >/dev/null 2>&1; then
  fail_test "non-ancestor trusted base ref was accepted"
fi
[[ ! -s "$dispatch_log" ]] \
  || fail_test "non-ancestor base ref reached a release verification dependency"

printf 'PASS: PR bootstrap dispatch preserves valid base state, rejects pinned-to-placeholder regressions, requires topology for repins, and rejects untrusted bases.\n'

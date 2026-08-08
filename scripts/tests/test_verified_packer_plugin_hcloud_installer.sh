#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
installer="$repo_root/packer-template/scripts/install-verified-packer-plugin-hcloud.sh"
temp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT HUP INT TERM

fail_test() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_failure() {
  local label="$1"
  shift
  if ("$@") > "$temp_dir/$label.stdout" 2> "$temp_dir/$label.stderr"; then
    fail_test "$label unexpectedly succeeded"
  fi
}

# Source the production helper so its archive and installation primitives are
# tested without adding digest or platform overrides to the executable API.
# shellcheck disable=SC1090,SC1091
source "$installer"
# shellcheck disable=SC2154
fixture_description="$expected_plugin_description"

grep -Fq -- '--connect-timeout 20 --max-time 300' "$installer" \
  || fail_test "production plugin download is missing bounded network timeouts"
grep -Fq -- '--max-filesize 268435456' "$installer" \
  || fail_test "production plugin download is missing a size bound"

[[ "$(resolve_platform Darwin x86_64)" == darwin_amd64 ]] || fail_test "Darwin amd64 mapping failed"
[[ "$(resolve_platform Darwin arm64)" == darwin_arm64 ]] || fail_test "Darwin arm64 mapping failed"
[[ "$(resolve_platform Linux x86_64)" == linux_amd64 ]] || fail_test "Linux amd64 mapping failed"
[[ "$(resolve_platform Linux aarch64)" == linux_arm64 ]] || fail_test "Linux arm64 mapping failed"
expect_failure unsupported-platform resolve_platform Plan9 x86_64
for platform in darwin_amd64 darwin_arm64 linux_amd64 linux_arm64; do
  digest="$(expected_archive_sha256 "$platform")"
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || fail_test "$platform digest pin is malformed"
done

fixture_dir="$temp_dir/fixture"
mkdir -p "$fixture_dir"
binary_name=packer-plugin-hcloud_v1.7.2_x5.0_linux_amd64
cat > "$fixture_dir/$binary_name" <<EOF
#!/usr/bin/env bash
printf '%s\\n' '$fixture_description'
EOF
chmod +x "$fixture_dir/$binary_name"
valid_archive="$temp_dir/valid.zip"
(
  cd "$fixture_dir"
  zip -q "$valid_archive" "$binary_name"
)

verify_sha256 "$valid_archive" "$(sha256_file "$valid_archive")"
expect_failure wrong-digest verify_sha256 "$valid_archive" "$(printf '0%.0s' {1..64})"
verify_archive_shape "$valid_archive" "$binary_name"
verify_plugin_metadata "$fixture_dir/$binary_name"

printf 'extra\n' > "$fixture_dir/extra-file"
extra_archive="$temp_dir/extra.zip"
(
  cd "$fixture_dir"
  zip -q "$extra_archive" "$binary_name" extra-file
)
expect_failure extra-archive-member verify_archive_shape "$extra_archive" "$binary_name"

cat > "$fixture_dir/wrong-metadata" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"version":"9.9.9","api_version":"x5.0"}'
EOF
chmod +x "$fixture_dir/wrong-metadata"
expect_failure wrong-metadata verify_plugin_metadata "$fixture_dir/wrong-metadata"

fake_packer="$temp_dir/fake-packer"
cat > "$fake_packer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  version)
    printf 'Packer v1.16.0\n'
    ;;
  plugins)
    case "${2:-}" in
      install)
        printf 'PACKER_PLUGIN_PATH=%s\n' "${PACKER_PLUGIN_PATH-<unset>}" > "$PACKER_TEST_LOG"
        printf '%s\n' "$@" >> "$PACKER_TEST_LOG"
        ;;
      installed)
        printf '/plugins/packer-plugin-hcloud_v1.7.2_x5.0_linux_amd64\n'
        ;;
      *) exit 2 ;;
    esac
    ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fake_packer"
verify_packer_version "$fake_packer"

explicit_log="$temp_dir/explicit-plugin-path.log"
PACKER_PLUGIN_PATH="$temp_dir/explicit-plugins" PACKER_TEST_LOG="$explicit_log" \
  install_plugin "$fixture_dir/$binary_name" "$binary_name" "$fake_packer"
grep -Fq "PACKER_PLUGIN_PATH=$temp_dir/explicit-plugins" "$explicit_log" \
  || fail_test "explicit PACKER_PLUGIN_PATH was not preserved"

default_log="$temp_dir/default-plugin-path.log"
(
  unset PACKER_PLUGIN_PATH
  export PACKER_TEST_LOG="$default_log"
  install_plugin "$fixture_dir/$binary_name" "$binary_name" "$fake_packer"
)
grep -Fq 'PACKER_PLUGIN_PATH=<unset>' "$default_log" \
  || fail_test "normal Packer plugin location path was not preserved"

# The executable entry point must reject an arbitrary local archive against the
# production platform digest before installation.
expect_failure executable-wrong-digest env PACKER_BIN="$fake_packer" "$installer" "$valid_archive"
grep -Fq 'hcloud Packer plugin archive digest mismatch' "$temp_dir/executable-wrong-digest.stderr" \
  || fail_test "executable wrong-digest case failed for an unexpected reason"

fake_bin="$temp_dir/fake-bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s) printf 'Plan9\n' ;;
  -m) printf 'x86_64\n' ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fake_bin/uname"
expect_failure executable-unsupported-platform env \
  PATH="$fake_bin:$PATH" PACKER_BIN="$fake_packer" "$installer"
grep -Fq 'unsupported hcloud Packer plugin platform: Plan9 x86_64' \
  "$temp_dir/executable-unsupported-platform.stderr" \
  || fail_test "executable unsupported-platform case failed for an unexpected reason"

printf 'PASS: verified hcloud Packer plugin helper unit and negative tests\n'

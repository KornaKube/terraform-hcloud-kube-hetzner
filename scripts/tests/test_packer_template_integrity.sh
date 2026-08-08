#!/usr/bin/env bash
# shellcheck disable=SC2016 # HCL interpolation strings below must remain literal.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
template="$repo_root/packer-template/hcloud-leapmicro-snapshots.pkr.hcl"
workflow_dir="$repo_root/.github/workflows"
plugin_installer="$repo_root/packer-template/scripts/install-verified-packer-plugin-hcloud.sh"
packer_bin="${PACKER_BIN:-packer}"
temp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

grep -Fq 'required_version = "= 1.16.0"' "$template" \
  || fail "Packer 1.16.0 is not required exactly"
grep -Fq 'version = "= 1.7.2"' "$template" \
  || fail "hcloud plugin 1.7.2 is not required exactly"

for variable in \
  opensuse_leapmicro_x86_mirror_authorization_header \
  opensuse_leapmicro_arm_mirror_authorization_header; do
  block="$(awk -v name="$variable" '
    $0 == "variable \"" name "\" {" { capture = 1 }
    capture { print }
    capture && /^}/ { exit }
  ' "$template")"
  grep -Fq 'sensitive   = true' <<< "$block" || fail "$variable must be marked sensitive"
done

if grep -Fq 'opensuse_leapmicro_mirror_authorization_header' "$template"; then
  fail "a shared x86/ARM mirror credential can cross architecture or origin boundaries"
fi
grep -Fq 'MIRROR_AUTHORIZATION_HEADER=${var.opensuse_leapmicro_x86_mirror_authorization_header}' "$template" \
  || fail "x86 build does not use its dedicated mirror credential"
grep -Fq 'MIRROR_AUTHORIZATION_HEADER=${var.opensuse_leapmicro_arm_mirror_authorization_header}' "$template" \
  || fail "ARM build does not use its dedicated mirror credential"
[[ "$(grep -Fc 'use_env_var_file = true' "$template")" == 2 ]] \
  || fail "both image verifier provisioners must transport secrets through Packer environment files"

unpinned_actions="$(awk '
  /uses:[[:space:]]+/ {
    action = $0
    sub(/^.*uses:[[:space:]]*/, "", action)
    sub(/[[:space:]]*#.*/, "", action)
    if (action ~ /^([.][.]?\/|docker:\/\/)/) next

    reference = action
    sub(/^.*@/, "", reference)
    if (action !~ /@/ || length(reference) != 40 || reference ~ /[^0-9a-f]/ || $0 !~ /#[[:space:]]+v[0-9]/) {
      print FILENAME ":" FNR ":" $0
    }
  }
' "$workflow_dir"/*)"
[[ -z "$unpinned_actions" ]] \
  || fail "GitHub Actions references must use reviewed commit SHAs with version comments: $unpinned_actions"

if grep 'qemu-img' "$template" | grep -Eq '(ls|grep|find|\$\(|`|\*|\?|\[)'; then
  fail "qemu-img input must not be rediscovered with a command substitution or pattern"
fi

x86_path=/root/openSUSE-Leap-Micro.x86_64-Default-qcow.qcow2
arm_path=/root/openSUSE-Leap-Micro.aarch64-Default-qcow.qcow2
grep -Fq "qemu-img convert -p -f qcow2 -O host_device '\${local.opensuse_leapmicro_x86_image_path}' /dev/sda" "$template" \
  || fail "x86 conversion does not use its fixed quoted appliance path"
grep -Fq "qemu-img convert -p -f qcow2 -O host_device '\${local.opensuse_leapmicro_arm_image_path}' /dev/sda" "$template" \
  || fail "ARM conversion does not use its fixed quoted appliance path"

# A second matching filename must not alter the explicitly selected conversion input.
fixture_dir="$temp_dir/qcow2-fixture"
mkdir -p "$fixture_dir/bin"
trusted_image="$fixture_dir/$(basename "$x86_path")"
extra_image="$fixture_dir/openSUSE-extra-Leap-Micro-decoy.qcow2"
printf 'trusted\n' > "$trusted_image"
printf 'untrusted\n' > "$extra_image"
cat > "$fixture_dir/bin/qemu-img" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$QEMU_ARGUMENT_LOG"
EOF
chmod +x "$fixture_dir/bin/qemu-img"
QEMU_ARGUMENT_LOG="$fixture_dir/qemu-arguments" \
  PATH="$fixture_dir/bin:$PATH" \
  qemu-img convert -p -f qcow2 -O host_device "$trusted_image" "$fixture_dir/device"
[[ "$(sed -n '7p' "$fixture_dir/qemu-arguments")" == "$trusted_image" ]] \
  || fail "extra matching qcow2 file changed the fixed conversion input"

command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v "$packer_bin" >/dev/null 2>&1 || fail "Packer is required"
[[ -x "$plugin_installer" ]] || fail "verified hcloud plugin installer is missing or not executable"

x86_write_script="$(printf 'local.write_x86_image\n' | "$packer_bin" console "$template")"
arm_write_script="$(printf 'local.write_arm_image\n' | "$packer_bin" console "$template")"
grep -Fq "qemu-img convert -p -f qcow2 -O host_device '$x86_path' /dev/sda" <<< "$x86_write_script" \
  || fail "rendered x86 conversion does not use its fixed quoted appliance path"
grep -Fq "qemu-img convert -p -f qcow2 -O host_device '$arm_path' /dev/sda" <<< "$arm_write_script" \
  || fail "rendered ARM conversion does not use its fixed quoted appliance path"

plugin_root="${PACKER_PLUGIN_PATH:-$temp_dir/packer-plugins}"
PACKER_PLUGIN_PATH="$plugin_root" PACKER_BIN="$packer_bin" "$plugin_installer"
required_plugins="$(PACKER_PLUGIN_PATH="$plugin_root" "$packer_bin" plugins required "$template")"
grep -Fq 'packer-plugin-hcloud_v1.7.2_x5.0_' <<< "$required_plugins" \
  || fail "Packer did not resolve the verified hcloud plugin"

printf 'PASS: canonical appliance paths ignore extra matching qcow2 files\n'
printf 'PASS: production helper installed the verified hcloud plugin archive\n'

#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
installer="$repo_root/packer-template/scripts/install-verified-rancher-rpm.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_bin="$tmp/bin"
verifier="$tmp/verify-rancher-rpm.sh"
key_file="$tmp/rancher.asc"
log_file="$tmp/calls.log"
expected_nevra=$'k3s-selinux\t0\t1.6\t1.slemicro\tnoarch'
mkdir "$fake_bin"
printf 'fixture-key\n' > "$key_file"

cat > "$verifier" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ -n "${OUTPUT_RPM_FILE:-}" ]] || exit 2
for variable in RPM_URL EXPECTED_RELEASE_TAG EXPECTED_PACKAGE_FILE EXPECTED_PACKAGE_NAME EXPECTED_RPM_SHA256 RANCHER_SIGNING_KEY_FILE RANCHER_SIGNING_KEY_FINGERPRINT; do
  [[ -n "${!variable:-}" ]] || exit 2
done
[[ "${KH_VERIFY_FAIL:-0}" == 0 ]] || exit 9
printf 'verified-rpm-fixture\n' > "$OUTPUT_RPM_FILE"
printf 'verify\n' >> "$KH_INSTALL_LOG"
EOF

cat > "$fake_bin/rpm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  -qp)
    [[ -f "${4:-}" ]] || exit 2
    printf '%s\n' "$KH_EXPECTED_NEVRA"
    ;;
  --import)
    [[ -f "${2:-}" ]] || exit 2
    printf 'import\n' >> "$KH_INSTALL_LOG"
    ;;
  -q)
    printf '%s\n' "${KH_INSTALLED_NEVRA:-$KH_EXPECTED_NEVRA}"
    printf 'query-installed\n' >> "$KH_INSTALL_LOG"
    ;;
  *)
    exit 2
    ;;
esac
EOF

cat > "$fake_bin/zypper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == --non-interactive && "${2:-}" == install && "${3:-}" == -y && -f "${4:-}" ]] || exit 2
printf 'install\n' >> "$KH_INSTALL_LOG"
EOF

chmod 700 "$verifier" "$fake_bin/rpm" "$fake_bin/zypper"

invoke_installer() {
  env \
    PATH="$fake_bin:$PATH" \
    KH_EXPECTED_NEVRA="$expected_nevra" \
    KH_INSTALL_LOG="$log_file" \
    KH_INSTALLED_NEVRA="${KH_INSTALLED_NEVRA:-}" \
    KH_VERIFY_FAIL="${KH_VERIFY_FAIL:-0}" \
    RPM_URL=https://github.com/k3s-io/k3s-selinux/releases/download/v1.6.stable.1/k3s-selinux-1.6-1.slemicro.noarch.rpm \
    EXPECTED_RELEASE_TAG=v1.6.stable.1 \
    EXPECTED_PACKAGE_FILE=k3s-selinux-1.6-1.slemicro.noarch.rpm \
    EXPECTED_PACKAGE_NAME=k3s-selinux \
    EXPECTED_RPM_SHA256=583f4b3d5f838e9e2bb450f7cc60142de15fc2deaa56687d15b07a73b80b8836 \
    RANCHER_RPM_VERIFIER_FILE="$verifier" \
    RANCHER_SIGNING_KEY_FILE="$key_file" \
    RANCHER_SIGNING_KEY_FINGERPRINT=C8CFF216455126E9B9C918BE925EA29AE257814A \
    "$installer"
}

invoke_installer
[[ "$(tr '\n' ' ' < "$log_file")" == 'verify import install query-installed ' ]] \
  || { echo 'FAIL: installer did not execute verify/import/install/readback in order' >&2; exit 1; }

if KH_INSTALLED_NEVRA=$'k3s-selinux\t0\t1.7\t1.slemicro\tnoarch' invoke_installer > "$tmp/mismatch.log" 2>&1; then
  echo 'FAIL: installer accepted a mismatched installed NEVRA' >&2
  exit 1
fi
grep -Fq 'installed SELinux RPM identity does not match' "$tmp/mismatch.log" \
  || { echo 'FAIL: installer mismatch returned the wrong error' >&2; exit 1; }

before_failure_calls="$(wc -l < "$log_file")"
if KH_VERIFY_FAIL=1 invoke_installer > "$tmp/verify-failure.log" 2>&1; then
  echo 'FAIL: installer continued after verifier failure' >&2
  exit 1
fi
after_failure_calls="$(wc -l < "$log_file")"
[[ "$before_failure_calls" == "$after_failure_calls" ]] \
  || { echo 'FAIL: installer mutated RPM state after verifier failure' >&2; exit 1; }

echo 'PASS: Rancher RPM installer verifies first, installs locally, and requires exact NEVRA readback.'

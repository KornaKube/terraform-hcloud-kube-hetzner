#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
verifier="$repo_root/packer-template/scripts/verify-rancher-rpm.sh"
signed_rpm="${RANCHER_SIGNED_RPM_FILE:-}"
[[ -f "$signed_rpm" ]] || { echo 'FAIL: RANCHER_SIGNED_RPM_FILE must identify the pinned k3s RPM' >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
unsigned_rpm="$tmp/unsigned.rpm"
fake_bin="$tmp/bin"
mkdir "$fake_bin"
cp "$signed_rpm" "$unsigned_rpm"
rpm --delsign "$unsigned_rpm"
unsigned_sha256="$(sha256sum "$unsigned_rpm" | awk '{ print tolower($1) }')"

cat > "$fake_bin/wget" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
destination=""
while (($#)); do
  case "$1" in
    -O)
      destination="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
[[ -n "$destination" ]] || exit 2
cp "$KH_UNSIGNED_RPM" "$destination"
EOF
chmod 700 "$fake_bin/wget"

failure_log="$tmp/failure.log"
if env \
  PATH="$fake_bin:$PATH" \
  KH_UNSIGNED_RPM="$unsigned_rpm" \
  RPM_URL=https://github.com/k3s-io/k3s-selinux/releases/download/v1.6.stable.1/k3s-selinux-1.6-1.slemicro.noarch.rpm \
  EXPECTED_RELEASE_TAG=v1.6.stable.1 \
  EXPECTED_PACKAGE_FILE=k3s-selinux-1.6-1.slemicro.noarch.rpm \
  EXPECTED_PACKAGE_NAME=k3s-selinux \
  EXPECTED_RPM_SHA256="$unsigned_sha256" \
  OUTPUT_RPM_FILE="$tmp/output.rpm" \
  RANCHER_SIGNING_KEY_FILE="$repo_root/packer-template/keys/rancher-ci-signing-key.asc" \
  RANCHER_SIGNING_KEY_FINGERPRINT=C8CFF216455126E9B9C918BE925EA29AE257814A \
  "$verifier" > "$failure_log" 2>&1; then
  echo 'FAIL: Rancher RPM verifier accepted an unsigned package' >&2
  exit 1
fi
grep -Fq 'signature verification failed' "$failure_log" \
  || { echo 'FAIL: unsigned RPM returned the wrong verifier error' >&2; cat "$failure_log" >&2; exit 1; }

echo 'PASS: Rancher RPM verifier rejects a digest-matched package without a publisher signature.'

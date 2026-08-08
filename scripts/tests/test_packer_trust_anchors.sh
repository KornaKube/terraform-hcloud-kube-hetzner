#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
template="$repo_root/packer-template/hcloud-leapmicro-snapshots.pkr.hcl"
now="$(date +%s)"
minimum_remaining_lifetime=$((90 * 24 * 60 * 60))

check_anchor() {
  local label="$1"
  local key_file="$2"
  local expected_fingerprint="$3"
  local expected_sha256="$4"

  local actual_sha256
  actual_sha256="$(sha256sum "$key_file" | awk '{ print tolower($1) }')"
  [[ "$actual_sha256" == "$expected_sha256" ]] \
    || { echo "FAIL: $label trust-anchor file SHA-256 mismatch" >&2; exit 1; }

  local key_rows
  key_rows="$(gpg --batch --show-keys --with-colons "$key_file" 2>/dev/null | awk -F: '
    $1 == "pub" { validity = $2; created = $6; expiry = ($7 == "" ? 0 : $7); capabilities = $12; primary = 1; next }
    primary && $1 == "fpr" { print $10 "|" validity "|" created "|" expiry "|" capabilities; primary = 0 }
  ')"
  [[ "$(awk 'NF { count++ } END { print count + 0 }' <<< "$key_rows")" == 1 ]] \
    || { echo "FAIL: $label key bundle must contain exactly one primary key" >&2; exit 1; }

  local fingerprint validity created expiry capabilities
  IFS='|' read -r fingerprint validity created expiry capabilities <<< "$key_rows"
  [[ "$fingerprint" == "$expected_fingerprint" ]] \
    || { echo "FAIL: $label fingerprint mismatch" >&2; exit 1; }
  case "$validity" in
    - | u | f | m) ;;
    *)
      echo "FAIL: $label trust anchor is revoked, expired, disabled, or invalid" >&2
      exit 1
      ;;
  esac
  [[ "$created" =~ ^[0-9]+$ && "$expiry" =~ ^[0-9]+$ ]] \
    || { echo "FAIL: $label trust-anchor lifecycle is malformed" >&2; exit 1; }
  [[ "$capabilities" == *s* || "$capabilities" == *S* ]] \
    || { echo "FAIL: $label trust anchor is not signing-capable" >&2; exit 1; }
  if [[ "$expiry" != 0 && "$expiry" -le $((now + minimum_remaining_lifetime)) ]]; then
    echo "FAIL: $label trust anchor expires in less than 90 days" >&2
    exit 1
  fi
  grep -Fq "$expected_fingerprint" "$template" \
    || { echo "FAIL: $label fingerprint is not pinned in the Packer template" >&2; exit 1; }
  echo "PASS: $label trust anchor $expected_fingerprint"
}

check_anchor \
  openSUSE \
  "$repo_root/packer-template/keys/opensuse-project-signing-key.asc" \
  AD485664E901B867051AB15F35A2F86E29B700A4 \
  b5745739ebfb95b25b8e810f9bcb847fe750ccda598bd85f02f0e974599a6d7e
check_anchor \
  Rancher \
  "$repo_root/packer-template/keys/rancher-ci-signing-key.asc" \
  C8CFF216455126E9B9C918BE925EA29AE257814A \
  7d2415f7fc532c365c8874bfad966566daaa0d04a9a5ba14d1db6080a9c12629

#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  return 1
}

classify_release_bootstrap_readme() {
  local readme="$1"
  local assignment_count begin_count begin_line bootstrap end_count end_line exact_assignment_count placeholder_count

  begin_count="$(grep -Ec '^# BEGIN_KH_VERIFIED_BOOTSTRAP$' "$readme" || true)"
  end_count="$(grep -Ec '^# END_KH_VERIFIED_BOOTSTRAP$' "$readme" || true)"
  if [[ "$begin_count" != 1 || "$end_count" != 1 ]]; then
    fail "README must contain exactly one verified bootstrap block"
    return 1
  fi
  begin_line="$(grep -n '^# BEGIN_KH_VERIFIED_BOOTSTRAP$' "$readme" | cut -d: -f1)"
  end_line="$(grep -n '^# END_KH_VERIFIED_BOOTSTRAP$' "$readme" | cut -d: -f1)"
  if [[ "$begin_line" -ge "$end_line" ]]; then
    fail "README verified bootstrap markers are out of order"
    return 1
  fi

  bootstrap="$(awk '
    /^# BEGIN_KH_VERIFIED_BOOTSTRAP$/ { capture=1; next }
    /^# END_KH_VERIFIED_BOOTSTRAP$/ { capture=0; next }
    capture { print }
  ' "$readme")" || {
    fail "README verified bootstrap block could not be extracted"
    return 1
  }

  assignment_count="$(grep -Ec 'kh_(commit|archive_sha256|manifest_sha256)[[:space:]]*=' <<< "$bootstrap" || true)"
  exact_assignment_count="$(grep -Ec '^  kh_(commit|archive_sha256|manifest_sha256)="[^"]*"$' <<< "$bootstrap" || true)"
  if [[ "$assignment_count" != 3 || "$exact_assignment_count" != 3 ]]; then
    fail "verified bootstrap must contain only the three canonical pin assignments"
    return 1
  fi

  for field in kh_commit kh_archive_sha256 kh_manifest_sha256; do
    if [[ "$(grep -Ec "^  ${field}=\"[^\"]*\"$" <<< "$bootstrap" || true)" != 1 ]]; then
      fail "verified bootstrap must contain exactly one canonical $field assignment"
      return 1
    fi
  done

  placeholder_count="$(grep -Ec '^  (kh_commit="__KH_SOURCE_COMMIT__"|kh_archive_sha256="__KH_SOURCE_ARCHIVE_SHA256__"|kh_manifest_sha256="__KH_PACKER_BUNDLE_MANIFEST_SHA256__")$' <<< "$bootstrap" || true)"
  case "$placeholder_count" in
    3)
      printf 'placeholders\n'
      ;;
    0)
      printf 'pinned\n'
      ;;
    *)
      fail "README release bootstrap is partially pinned"
      return 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi

cd "$repo_root"
state="$(classify_release_bootstrap_readme README.md)"
case "$state" in
  placeholders)
    printf 'PASS: functional candidate retains all three exact release pin placeholders.\n'
    ;;
  pinned)
    scripts/check-release-bootstrap-topology.sh HEAD
    scripts/tests/test_readme_release_bootstrap.sh --require-pinned
    ;;
  *)
    fail "unrecognized release bootstrap state"
    ;;
esac

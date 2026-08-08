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

release_bootstrap_pins_at_ref() {
  local ref="$1"

  git show "${ref}:README.md" | sed -n '/^# BEGIN_KH_VERIFIED_BOOTSTRAP$/,/^# END_KH_VERIFIED_BOOTSTRAP$/p' \
    | grep -E '^  kh_(commit|archive_sha256|manifest_sha256)="[^"]*"$'
}

release_bootstrap_pins_match_base() {
  local base_ref="$1"
  local base_pins current_pins

  if ! git rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null; then
    printf 'ERROR: release bootstrap base ref is not a commit: %s\n' "$base_ref" >&2
    return 2
  fi
  if ! git merge-base --is-ancestor "$base_ref" HEAD; then
    printf 'ERROR: release bootstrap base ref is not an ancestor of HEAD: %s\n' "$base_ref" >&2
    return 2
  fi
  if ! base_pins="$(release_bootstrap_pins_at_ref "$base_ref")"; then
    printf 'ERROR: README is unavailable at release bootstrap base ref: %s\n' "$base_ref" >&2
    return 2
  fi
  current_pins="$(sed -n '/^# BEGIN_KH_VERIFIED_BOOTSTRAP$/,/^# END_KH_VERIFIED_BOOTSTRAP$/p' README.md \
    | grep -E '^  kh_(commit|archive_sha256|manifest_sha256)="[^"]*"$')"

  [[ "$current_pins" == "$base_pins" ]]
}

functional_bootstrap_pins_match_base() {
  local base_ref="$1"
  local base_pins functional_pins functional_ref

  functional_ref="$(sed -n 's/^  kh_commit="\([^"]*\)"$/\1/p' README.md)"
  if ! git rev-parse --verify --quiet "${functional_ref}^{commit}" >/dev/null; then
    printf 'ERROR: pinned functional commit is unavailable: %s\n' "$functional_ref" >&2
    return 2
  fi
  if ! base_pins="$(release_bootstrap_pins_at_ref "$base_ref")"; then
    printf 'ERROR: base bootstrap pins are unavailable: %s\n' "$base_ref" >&2
    return 2
  fi
  if ! functional_pins="$(release_bootstrap_pins_at_ref "$functional_ref")"; then
    printf 'ERROR: functional bootstrap pins are unavailable: %s\n' "$functional_ref" >&2
    return 2
  fi

  [[ "$functional_pins" == "$base_pins" ]]
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi

cd "$repo_root"
state="$(classify_release_bootstrap_readme README.md)"
base_ref="${KH_RELEASE_BASE_REF:-refs/remotes/origin/master}"
base_match_status=0
release_bootstrap_pins_match_base "$base_ref" || base_match_status=$?
case "$state" in
  placeholders)
    case "$base_match_status" in
      0)
        printf 'PASS: placeholder bootstrap block is unchanged from trusted base %s.\n' "$base_ref"
        ;;
      1)
        fail "a pinned bootstrap may not be reverted to placeholders; retain the previous release pins in functional commit A"
        exit 1
        ;;
      *)
        exit "$base_match_status"
        ;;
    esac
    scripts/tests/test_readme_release_bootstrap.sh
    ;;
  pinned)
    case "$base_match_status" in
      0)
        printf 'PASS: pinned bootstrap block is unchanged from trusted base %s.\n' "$base_ref"
        ;;
      1)
        functional_match_status=0
        functional_bootstrap_pins_match_base "$base_ref" || functional_match_status=$?
        case "$functional_match_status" in
          0) ;;
          1)
            fail "functional commit A must retain the trusted base bootstrap pins"
            exit 1
            ;;
          *)
            exit "$functional_match_status"
            ;;
        esac
        scripts/check-release-bootstrap-topology.sh HEAD
        ;;
      *)
        exit "$base_match_status"
        ;;
    esac
    scripts/tests/test_readme_release_bootstrap.sh --require-pinned
    ;;
  *)
    fail "unrecognized release bootstrap state"
    ;;
esac

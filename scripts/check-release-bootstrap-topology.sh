#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
require_merge=false
case "${1:-}" in
  --require-merge)
    require_merge=true
    shift
    ;;
esac
[[ "$#" -le 1 ]] || { printf 'usage: %s [--require-merge] [release-ref]\n' "$0" >&2; exit 2; }
release_ref="${1:-HEAD}"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print tolower($1) }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print tolower($1) }'
  else
    fail "sha256sum or shasum is required"
  fi
}

extract_pin() {
  local field="$1"
  local readme="$2"
  sed -n "s/^  ${field}=\"\([^\"]*\)\"$/\\1/p" "$readme"
}

normalize_pin_lines() {
  awk '
    /^  kh_commit=/ { print "  kh_commit=\"__KH_SOURCE_COMMIT__\""; next }
    /^  kh_archive_sha256=/ { print "  kh_archive_sha256=\"__KH_SOURCE_ARCHIVE_SHA256__\""; next }
    /^  kh_manifest_sha256=/ { print "  kh_manifest_sha256=\"__KH_PACKER_BUNDLE_MANIFEST_SHA256__\""; next }
    { print }
  ' "$1"
}

classify_functional_pins() {
  local readme="$1"
  local commit archive_sha256 manifest_sha256

  commit="$(extract_pin kh_commit "$readme")"
  archive_sha256="$(extract_pin kh_archive_sha256 "$readme")"
  manifest_sha256="$(extract_pin kh_manifest_sha256 "$readme")"

  if [[ "$commit" == "__KH_SOURCE_COMMIT__" &&
        "$archive_sha256" == "__KH_SOURCE_ARCHIVE_SHA256__" &&
        "$manifest_sha256" == "__KH_PACKER_BUNDLE_MANIFEST_SHA256__" ]]; then
    printf 'placeholders\n'
  elif [[ "$commit" =~ ^[0-9a-f]{40}$ &&
          "$archive_sha256" =~ ^[0-9a-f]{64}$ &&
          "$manifest_sha256" =~ ^[0-9a-f]{64}$ ]]; then
    printf 'pinned\n'
  else
    fail "functional README must retain either three previous release pins or three exact placeholders"
  fi
}

cd "$repo_root"
git cat-file -e "${release_ref}^{commit}" 2>/dev/null \
  || fail "release ref is not a commit: $release_ref"
release_commit="$(git rev-parse "${release_ref}^{commit}")"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git show "${release_commit}:README.md" > "$tmp/release-readme"

functional_commit="$(extract_pin kh_commit "$tmp/release-readme")"
archive_sha256="$(extract_pin kh_archive_sha256 "$tmp/release-readme")"
manifest_sha256="$(extract_pin kh_manifest_sha256 "$tmp/release-readme")"

[[ "$functional_commit" =~ ^[0-9a-f]{40}$ ]] \
  || fail "README does not pin a full lowercase functional commit"
[[ "$archive_sha256" =~ ^[0-9a-f]{64}$ ]] \
  || fail "README does not pin a lowercase source archive SHA-256"
[[ "$manifest_sha256" =~ ^[0-9a-f]{64}$ ]] \
  || fail "README does not pin a lowercase Packer manifest SHA-256"
[[ "$functional_commit" != "$release_commit" ]] \
  || fail "release commit cannot pin itself as the functional commit"
git cat-file -e "${functional_commit}^{commit}" 2>/dev/null \
  || fail "pinned functional commit is absent from release history"
git merge-base --is-ancestor "$functional_commit" "$release_commit" \
  || fail "pinned functional commit is not an ancestor of the release commit"

read -r -a release_graph <<< "$(git rev-list --parents -n 1 "$release_commit")"
release_parents=("${release_graph[@]:1}")
pin_commit=""

case "${#release_parents[@]}" in
  1)
    [[ "$require_merge" == false ]] \
      || fail "release ref must be the protected pull-request merge commit"
    [[ "${release_parents[0]}" == "$functional_commit" ]] \
      || fail "pin commit must be the direct child of the functional commit"
    pin_commit="$release_commit"
    ;;
  2)
    pin_parent_index=-1
    for index in 0 1; do
      parent="${release_parents[$index]}"
      read -r -a parent_graph <<< "$(git rev-list --parents -n 1 "$parent")"
      parent_parents=("${parent_graph[@]:1}")
      if [[ "${#parent_parents[@]}" == 1 && "${parent_parents[0]}" == "$functional_commit" ]]; then
        [[ "$pin_parent_index" == -1 ]] \
          || fail "release merge has more than one candidate pin parent"
        pin_parent_index="$index"
        pin_commit="$parent"
      fi
    done
    [[ "$pin_parent_index" != -1 ]] \
      || fail "release merge does not have the direct A-to-B pin commit as a parent"
    base_parent_index=$((1 - pin_parent_index))
    base_parent="${release_parents[$base_parent_index]}"
    git merge-base --is-ancestor "$base_parent" "$functional_commit" \
      || fail "release merge base parent is not already ancestral to the functional commit"
    [[ "$(git rev-parse "${release_commit}^{tree}")" == "$(git rev-parse "${pin_commit}^{tree}")" ]] \
      || fail "release merge tree differs from the verified pin commit"
    ;;
  *)
    fail "release ref must be exactly the pin commit or its two-parent protected merge"
    ;;
esac

changed_paths="$(git diff --name-only "$functional_commit" "$pin_commit")"
[[ "$changed_paths" == "README.md" ]] \
  || fail "pin commit may differ from the functional tree only in README.md"

functional_readme_mode="$(git ls-tree "$functional_commit" -- README.md | awk '{ print $1 }')"
pin_readme_mode="$(git ls-tree "$pin_commit" -- README.md | awk '{ print $1 }')"
[[ -n "$functional_readme_mode" && "$pin_readme_mode" == "$functional_readme_mode" ]] \
  || fail "README file mode changed after the functional commit"

git show "${functional_commit}:README.md" > "$tmp/functional-readme"
classify_functional_pins "$tmp/functional-readme" >/dev/null

normalize_pin_lines "$tmp/functional-readme" > "$tmp/normalized-functional-readme"
normalize_pin_lines "$tmp/release-readme" > "$tmp/normalized-release-readme"
cmp -s "$tmp/normalized-functional-readme" "$tmp/normalized-release-readme" \
  || fail "README changed outside the three release bootstrap pin assignments"

git show "${functional_commit}:packer-template/security-bundle.sha256" > "$tmp/security-bundle.sha256"
[[ "$(sha256_file "$tmp/security-bundle.sha256")" == "$manifest_sha256" ]] \
  || fail "README manifest pin does not match the functional commit"

printf 'PASS: release tree %s preserves strict A-to-B history from %s plus only the three verified README pins.\n' \
  "$release_commit" "$functional_commit"

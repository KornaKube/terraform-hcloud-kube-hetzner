#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
require_tip=false
case "${1:-}" in
  --require-tip)
    require_tip=true
    shift
    ;;
esac
[[ "$#" -le 2 ]] || { printf 'usage: %s [--require-tip] [candidate-ref] [remote-branch-ref]\n' "$0" >&2; exit 2; }
candidate_ref="${1:-HEAD}"
remote_branch_ref="${2:-refs/remotes/origin/master}"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

cd "$repo_root"
git cat-file -e "${candidate_ref}^{commit}" 2>/dev/null \
  || fail "release candidate ref is not a commit: $candidate_ref"
git cat-file -e "${remote_branch_ref}^{commit}" 2>/dev/null \
  || fail "authoritative remote default-branch ref is not a commit: $remote_branch_ref"

candidate_commit="$(git rev-parse "${candidate_ref}^{commit}")"
remote_branch_commit="$(git rev-parse "${remote_branch_ref}^{commit}")"

if [[ "$require_tip" == true ]]; then
  [[ "$candidate_commit" == "$remote_branch_commit" ]] \
    || fail "release candidate is not the fetched remote default-branch tip"
else
  git merge-base --is-ancestor "$candidate_commit" "$remote_branch_commit" \
    || fail "release candidate is not contained in the fetched remote default branch"
fi

printf 'PASS: release candidate %s is authoritative on %s.\n' \
  "$candidate_commit" "$remote_branch_ref"

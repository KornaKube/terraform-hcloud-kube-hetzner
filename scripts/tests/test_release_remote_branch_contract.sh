#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
checker_source="$repo_root/scripts/check-release-ref-on-remote-default-branch.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/repository"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_rejected() {
  local label="$1"
  shift
  if "$fixture/scripts/check-release-ref-on-remote-default-branch.sh" "$@" >"$tmp/$label.log" 2>&1; then
    fail "$label was accepted"
  fi
}

mkdir -p "$fixture/scripts"
cp "$checker_source" "$fixture/scripts/check-release-ref-on-remote-default-branch.sh"
chmod 700 "$fixture/scripts/check-release-ref-on-remote-default-branch.sh"
git -C "$fixture" init -q
git -C "$fixture" config user.name 'Remote Branch Contract Test'
git -C "$fixture" config user.email 'remote-contract@example.invalid'
printf '%s\n' base > "$fixture/content"
git -C "$fixture" add .
git -C "$fixture" commit -q -m base
candidate_commit="$(git -C "$fixture" rev-parse HEAD)"
git -C "$fixture" update-ref refs/remotes/origin/master "$candidate_commit"

"$fixture/scripts/check-release-ref-on-remote-default-branch.sh" --require-tip HEAD refs/remotes/origin/master >/dev/null \
  || fail "authoritative remote tip was rejected"

printf '%s\n' newer >> "$fixture/content"
git -C "$fixture" add content
git -C "$fixture" commit -q -m newer
remote_tip="$(git -C "$fixture" rev-parse HEAD)"
git -C "$fixture" update-ref refs/remotes/origin/master "$remote_tip"
"$fixture/scripts/check-release-ref-on-remote-default-branch.sh" "$candidate_commit" refs/remotes/origin/master >/dev/null \
  || fail "published ancestor of the current remote branch was rejected"
expect_rejected stale-tip --require-tip "$candidate_commit" refs/remotes/origin/master

git -C "$fixture" checkout -q -b unpublished "$candidate_commit"
printf '%s\n' local-only > "$fixture/local-only"
git -C "$fixture" add local-only
git -C "$fixture" commit -q -m local-only
expect_rejected unpublished-local-commit HEAD refs/remotes/origin/master
expect_rejected missing-remote-ref HEAD refs/remotes/origin/missing

printf 'PASS: release refs must equal the fetched default-branch tip before tagging and remain contained at publication.\n'

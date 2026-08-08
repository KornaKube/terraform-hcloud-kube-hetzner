#!/usr/bin/env bash

set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

remote="$tmp/remote.git"
publisher="$tmp/publisher"
contender="$tmp/contender"

git init --bare --initial-branch=master "$remote" >/dev/null
git clone --quiet "$remote" "$publisher"
git -C "$publisher" config user.name "Release Fixture"
git -C "$publisher" config user.email "release-fixture@example.invalid"
git -C "$publisher" config commit.gpgSign false
git -C "$publisher" config tag.gpgSign false
git -C "$publisher" commit --allow-empty -m "functional release tree" >/dev/null
git -C "$publisher" push --quiet origin HEAD:master

release_commit="$(git -C "$publisher" rev-parse HEAD)"
git -C "$publisher" tag -a v-fixture "$release_commit" -m "fixture release"
git -C "$publisher" push --atomic \
  --force-with-lease="refs/heads/master:$release_commit" \
  origin "${release_commit}:refs/heads/master" refs/tags/v-fixture >/dev/null

published_commit="$(git --git-dir="$remote" rev-parse 'refs/tags/v-fixture^{}')"
[[ "$published_commit" == "$release_commit" ]] \
  || { printf 'FAIL: explicit release tag did not target the reviewed commit\n' >&2; exit 1; }

git clone --quiet "$remote" "$contender"
git -C "$contender" config user.name "Concurrent Fixture"
git -C "$contender" config user.email "concurrent-fixture@example.invalid"
git -C "$contender" config commit.gpgSign false
git -C "$contender" commit --allow-empty -m "concurrent protected-master advance" >/dev/null
git -C "$contender" push --quiet origin master

git -C "$publisher" tag -a v-stale "$release_commit" -m "stale fixture release"
if git -C "$publisher" push --atomic \
  --force-with-lease="refs/heads/master:$release_commit" \
  origin "${release_commit}:refs/heads/master" refs/tags/v-stale >/dev/null 2>&1; then
  printf 'FAIL: stale protected-master lease was accepted\n' >&2
  exit 1
fi
if git --git-dir="$remote" rev-parse --verify refs/tags/v-stale >/dev/null 2>&1; then
  printf 'FAIL: atomic push leaked a tag after the branch lease failed\n' >&2
  exit 1
fi

printf 'PASS: explicit tag binding and atomic protected-master leases reject concurrent publication races.\n'

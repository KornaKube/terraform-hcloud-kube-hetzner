#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow="$repo_root/.github/workflows/publish-release.yaml"
lint_workflow="$repo_root/.github/workflows/lint_pr.yaml"
release_skill="$repo_root/.claude/skills/prepare-release/SKILL.md"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

grep -Fq -- "- 'v*'" "$workflow" || fail "release workflow must accept only v-prefixed tags"
if grep -Eq '^[[:space:]]+workflow_dispatch:' "$workflow"; then
  fail "release workflow must not execute a caller-selected workflow definition"
fi
grep -Fq 'contents: write' "$workflow" || fail "release job needs explicit contents write permission"
grep -Fq 'persist-credentials: false' "$workflow" || fail "release checkout credentials must not persist"
grep -Fq 'fetch-depth: 0' "$workflow" || fail "release topology gate needs complete commit history"
grep -Fq 'git fetch --no-tags origin master' "$workflow" \
  || fail "release workflow does not refresh authoritative master"
grep -Fq 'scripts/check-release-ref-on-remote-default-branch.sh HEAD refs/remotes/origin/master' "$workflow" \
  || fail "release workflow does not prove the tag target is contained in authoritative master"
grep -Fq 'scripts/check-release-bootstrap-topology.sh --require-merge HEAD' "$workflow" \
  || fail "release workflow does not enforce the protected-merge functional-tree topology"
grep -Fq 'scripts/tests/test_readme_release_bootstrap.sh --require-pinned' "$workflow" \
  || fail "release workflow does not execute the real pinned bootstrap gate"

remote_line="$(grep -n 'scripts/check-release-ref-on-remote-default-branch.sh HEAD refs/remotes/origin/master' "$workflow" | cut -d: -f1)"
topology_line="$(grep -n 'scripts/check-release-bootstrap-topology.sh --require-merge HEAD' "$workflow" | cut -d: -f1)"
release_line="$(grep -n 'uses: ncipollo/release-action@' "$workflow" | cut -d: -f1)"
[[ "$remote_line" -lt "$topology_line" && "$topology_line" -lt "$release_line" ]] \
  || fail "release tree must be verified before the release action executes"

grep -Fq 'scripts/tests/test_release_bootstrap_topology.sh' "$lint_workflow" \
  || fail "pull-request CI omits adversarial release topology fixtures"
grep -Fq 'scripts/tests/test_release_bootstrap_pr_gate.sh' "$lint_workflow" \
  || fail "pull-request CI omits adversarial release-state classification fixtures"
grep -Fq 'scripts/tests/test_release_remote_branch_contract.sh' "$lint_workflow" \
  || fail "pull-request CI omits adversarial authoritative-branch fixtures"
grep -Fq 'scripts/tests/test_release_atomic_tag_push.sh' "$lint_workflow" \
  || fail "pull-request CI omits the atomic tag-push race fixture"
grep -Fq 'scripts/check-release-bootstrap-pr-gate.sh' "$lint_workflow" \
  || fail "pull-request CI does not fail closed across placeholder and pinned states"
packer_job="$(sed -n '/^  packer-validate:/,/^  [a-zA-Z0-9_-]*:/p' "$lint_workflow")"
grep -Fq 'fetch-depth: 0' <<< "$packer_job" \
  || fail "required pull-request supply-chain job does not fetch the A/B history"
if grep -Fq "grep -Fq '__KH_SOURCE_COMMIT__' README.md" "$lint_workflow"; then
  fail "pull-request CI still uses the marker-in-prose bypassable classifier"
fi

grep -Fq '**merge-commit** method' "$release_skill" \
  || fail "release process does not forbid squash/rebase destruction of the A/B graph"
execute_release="$(sed -n '/^## Execute Release/,/^## Post-Release Verification/p' "$release_skill")"
if grep -Fq 'git pull origin master' <<< "$execute_release"; then
  fail "release execution still inherits unsafe local pull.ff behavior"
fi
initial_fetch_line="$(grep -n 'git fetch --no-tags origin master' <<< "$execute_release" | head -1 | cut -d: -f1)"
final_fetch_line="$(grep -n 'git fetch --no-tags origin master' <<< "$execute_release" | tail -1 | cut -d: -f1)"
merge_line="$(grep -n 'git merge --ff-only refs/remotes/origin/master' <<< "$execute_release" | cut -d: -f1)"
remote_line="$(grep -n "scripts/check-release-ref-on-remote-default-branch.sh --require-tip \"\$RELEASE_COMMIT\" refs/remotes/origin/master" <<< "$execute_release" | cut -d: -f1)"
controls_line="$(grep -n 'scripts/check-github-release-controls.sh' <<< "$execute_release" | cut -d: -f1)"
topology_line="$(grep -n 'scripts/check-release-bootstrap-topology.sh --require-merge HEAD' <<< "$execute_release" | cut -d: -f1)"
bootstrap_line="$(grep -n 'scripts/tests/test_readme_release_bootstrap.sh --require-pinned' <<< "$execute_release" | cut -d: -f1)"
head_line="$(grep -n "test \"\$(git rev-parse HEAD)\" = \"\$RELEASE_COMMIT\"" <<< "$execute_release" | cut -d: -f1)"
tag_line="$(grep -n "git tag -a \"\$VERSION\" \"\$RELEASE_COMMIT\" -m \"Release \$VERSION\"" <<< "$execute_release" | cut -d: -f1)"
push_line="$(grep -n "git push --atomic --force-with-lease=\"refs/heads/master:\$RELEASE_COMMIT\"" <<< "$execute_release" | cut -d: -f1)"
grep -Fq "\"\${RELEASE_COMMIT}:refs/heads/master\" \"refs/tags/\$VERSION\"" <<< "$execute_release" \
  || fail "release tag push does not atomically lease protected master"
[[ "$initial_fetch_line" -lt "$merge_line" && "$merge_line" -lt "$topology_line" && "$topology_line" -lt "$controls_line" && "$bootstrap_line" -lt "$controls_line" && "$controls_line" -lt "$final_fetch_line" && "$final_fetch_line" -lt "$remote_line" && "$remote_line" -lt "$head_line" && "$head_line" -lt "$tag_line" && "$tag_line" -lt "$push_line" ]] \
  || fail "slow immutable gates must precede final live controls, refreshed master, and lease-guarded tag publication"

printf 'PASS: release publishing is tag-only and rejects trees that escape the pinned functional commit.\n'

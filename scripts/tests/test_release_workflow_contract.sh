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
grep -Fq 'pull-requests: read' "$workflow" || fail "generated release notes need pull-request read permission"
grep -Fq 'persist-credentials: false' "$workflow" || fail "release checkout credentials must not persist"
grep -Fq "test \"\$(grep -Ec '^## \\[Unreleased\\]$' CHANGELOG.md)\" -eq 1" "$workflow" \
  || fail "release publication must require exactly one Unreleased section"
grep -Fq "grep -Eq '[^[:space:]]' changelog_section.md" "$workflow" \
  || fail "release publication must reject empty reviewed notes"
grep -Fq 'uses: ncipollo/release-action@339a81892b84b4eeb0f6e744e4574d79d0d9b8dd # v1.21.0' "$workflow" \
  || fail "release publication action must remain commit-pinned"
if grep -Eq 'HCLOUD_TOKEN|terraform|packer|gh api|filter-release-pr-authors|format-release-coauthors' "$workflow"; then
  fail "tag publication must not repeat local infrastructure gates or custom contributor API processing"
fi

extract_line="$(grep -n 'name: Extract reviewed changelog' "$workflow" | cut -d: -f1)"
release_line="$(grep -n 'uses: ncipollo/release-action@' "$workflow" | cut -d: -f1)"
[[ "$extract_line" -lt "$release_line" ]] || fail "reviewed changelog extraction must precede publication"

grep -Fq 'scripts/tests/test_create_distribution.sh' "$lint_workflow" \
  || fail "pull-request CI omits createkh distribution fixtures"
grep -Fq 'scripts/tests/test_generated_site_contract.sh' "$lint_workflow" \
  || fail "pull-request CI omits generated createkh documentation checks"
grep -Fq 'scripts/tests/test_release_remote_branch_contract.sh' "$lint_workflow" \
  || fail "pull-request CI omits adversarial authoritative-branch fixtures"
grep -Fq 'scripts/tests/test_release_atomic_tag_push.sh' "$lint_workflow" \
  || fail "pull-request CI omits the atomic tag-push race fixture"
[[ ! -e "$repo_root/.github/workflows/trusted_hcloud_smoke.yaml" ]] \
  || fail "GitHub-hosted HCloud smoke must be removed"

if rg -n 'functional commit A|A/B graph|bootstrap pin|check-release-bootstrap' "$release_skill"; then
  fail "release skill still carries obsolete README pin choreography"
fi
execute_release="$(sed -n '/^## Execute Release/,/^## Post-Release Verification/p' "$release_skill")"
if grep -Fq 'git pull origin master' <<< "$execute_release"; then
  fail "release execution still inherits unsafe local pull.ff behavior"
fi
initial_fetch_line="$(grep -n 'git fetch --no-tags origin master' <<< "$execute_release" | head -1 | cut -d: -f1)"
final_fetch_line="$(grep -n 'git fetch --no-tags origin master' <<< "$execute_release" | tail -1 | cut -d: -f1)"
merge_line="$(grep -n 'git merge --ff-only refs/remotes/origin/master' <<< "$execute_release" | cut -d: -f1)"
remote_line="$(grep -n "scripts/check-release-ref-on-remote-default-branch.sh --require-tip \"\$RELEASE_COMMIT\" refs/remotes/origin/master" <<< "$execute_release" | cut -d: -f1)"
controls_line="$(grep -n 'scripts/check-github-release-controls.sh' <<< "$execute_release" | cut -d: -f1)"
head_line="$(grep -n "test \"\$(git rev-parse HEAD)\" = \"\$RELEASE_COMMIT\"" <<< "$execute_release" | cut -d: -f1)"
tag_line="$(grep -n "git tag -a \"\$VERSION\" \"\$RELEASE_COMMIT\" -m \"Release \$VERSION\"" <<< "$execute_release" | cut -d: -f1)"
push_line="$(grep -n "git push --atomic --force-with-lease=\"refs/heads/master:\$RELEASE_COMMIT\"" <<< "$execute_release" | cut -d: -f1)"
grep -Fq "\"\${RELEASE_COMMIT}:refs/heads/master\" \"refs/tags/\$VERSION\"" <<< "$execute_release" \
  || fail "release tag push does not atomically lease protected master"
[[ "$initial_fetch_line" -lt "$merge_line" && "$merge_line" -lt "$controls_line" && "$controls_line" -lt "$final_fetch_line" && "$final_fetch_line" -lt "$remote_line" && "$remote_line" -lt "$head_line" && "$head_line" -lt "$tag_line" && "$tag_line" -lt "$push_line" ]] \
  || fail "local release preparation must precede live controls and lease-guarded tag publication"

printf 'PASS: cheap GitHub publication is tag-only while release integrity and cloud proof remain local.\n'

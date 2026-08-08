#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow="$repo_root/.github/workflows/trusted_hcloud_smoke.yaml"
# shellcheck disable=SC2016
input_expression='${{ inputs.commit }}'
# shellcheck disable=SC2016
secret_expression='${{ secrets.'
# shellcheck disable=SC2016
commit_guard='[[ ! "$CANDIDATE_COMMIT" =~ ^[0-9a-f]{40}$ ]]'
# shellcheck disable=SC2016
ancestry_guard='git merge-base --is-ancestor "$CANDIDATE_COMMIT" "$trusted_ref"'
# shellcheck disable=SC2016
detached_checkout='git -c advice.detachedHead=false checkout --detach "$CANDIDATE_COMMIT"'
# shellcheck disable=SC2016
default_branch_guard='[ "$EVENT_REF" != "refs/heads/$DEFAULT_BRANCH" ]'

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

grep -Fq 'commit:' "$workflow" \
  || fail "trusted smoke must require a commit input"
grep -Fq "CANDIDATE_COMMIT: $input_expression" "$workflow" \
  || fail "workflow input must cross into the shell through the environment"
[[ "$(grep -Fc "$input_expression" "$workflow")" -eq 1 ]] \
  || fail "candidate input must not be interpolated directly into run scripts"
if grep -Eq 'inputs[.]ref|ref:[[:space:]]*[$][{][{][[:space:]]*inputs[.]' "$workflow"; then
  fail "trusted smoke must not checkout a caller-selected branch, tag, or ref"
fi
grep -Fq 'fetch-depth: 0' "$workflow" \
  || fail "trusted default-branch history must be available for ancestry verification"
grep -Fq 'persist-credentials: false' "$workflow" \
  || fail "checkout credentials must not persist into candidate code"
grep -Fq "$commit_guard" "$workflow" \
  || fail "candidate must be constrained to one full lowercase commit SHA"
grep -Fq "$ancestry_guard" "$workflow" \
  || fail "candidate must be contained in the repository default branch"
grep -Fq "$detached_checkout" "$workflow" \
  || fail "verified candidate must be checked out detached"
grep -Fq "$default_branch_guard" "$workflow" \
  || fail "workflow must reject dispatches whose selected ref is not the default branch"

verify_line="$(grep -nF 'name: Verify and checkout merged candidate' "$workflow" | cut -d: -f1)"
hcloud_cli_line="$(grep -nF 'sudo apt-get install --yes hcloud-cli' "$workflow" | cut -d: -f1 || true)"
secret_line="$(grep -nF "$secret_expression" "$workflow" | head -n 1 | cut -d: -f1)"
[[ -n "$verify_line" && -n "$secret_line" && "$verify_line" -lt "$secret_line" ]] \
  || fail "candidate ancestry verification must precede every secret-bearing step"
[[ -n "$hcloud_cli_line" && "$hcloud_cli_line" -lt "$secret_line" ]] \
  || fail "the HCloud CLI required by the plan matrix must be installed before secret-bearing steps"

if grep -Eq '^[[:space:]]+(pull_request|pull_request_target):' "$workflow"; then
  fail "trusted HCloud smoke must remain manually dispatched"
fi

echo "PASS: trusted HCloud smoke exposes secrets only to a full commit already merged into the default branch."

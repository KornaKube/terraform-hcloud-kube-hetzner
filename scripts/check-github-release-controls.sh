#!/usr/bin/env bash

set -euo pipefail

readonly RELEASE_REPOSITORY="mysticaltech/terraform-hcloud-kube-hetzner"
readonly RELEASE_DEFAULT_BRANCH="master"
readonly RELEASE_MAINTAINER="mysticaltech"
readonly HCLOUD_SMOKE_ENVIRONMENT="hcloud-smoke"
readonly REQUIRED_STATUS_CHECK_CONTEXT="Validate Packer and supply-chain fixtures"
readonly REQUIRED_STATUS_CHECK_APP_ID=15368
readonly REQUIRED_BRANCH_RULESET="Restrict master updates to administrators"
readonly REQUIRED_TAG_RULESET="Protect v release tags"

verify_branch_protection() {
  jq -e \
    --arg context "$REQUIRED_STATUS_CHECK_CONTEXT" \
    --argjson app_id "$REQUIRED_STATUS_CHECK_APP_ID" '
    .enforce_admins.enabled == true and
    .required_pull_request_reviews != null and
    .required_pull_request_reviews.required_approving_review_count == 0 and
    .required_pull_request_reviews.require_code_owner_reviews == false and
    .required_pull_request_reviews.require_last_push_approval == false and
    .required_status_checks.strict == true and
    (.required_status_checks.checks | length) == 1 and
    .required_status_checks.checks[0].context == $context and
    .required_status_checks.checks[0].app_id == $app_id and
    .required_conversation_resolution.enabled == true and
    .allow_force_pushes.enabled == false and
    .allow_deletions.enabled == false and
    .required_linear_history.enabled == false and
    .lock_branch.enabled == false and
    .required_signatures.enabled == false and
    .restrictions == null
  ' >/dev/null <<< "$1"
}

verify_branch_deployment_requirements() {
  jq -e --arg branch "$RELEASE_DEFAULT_BRANCH" '
    .data.repository.ref.name == $branch and
    .data.repository.ref.branchProtectionRule != null and
    .data.repository.ref.branchProtectionRule.pattern == $branch and
    .data.repository.ref.branchProtectionRule.requiresDeployments == false and
    .data.repository.ref.branchProtectionRule.requiredDeploymentEnvironments == [] and
    .data.repository.ref.branchProtectionRule.bypassPullRequestAllowances != null and
    .data.repository.ref.branchProtectionRule.bypassPullRequestAllowances.totalCount == 0
  ' >/dev/null <<< "$1"
}

verify_repository_settings() {
  jq -e --arg branch "$RELEASE_DEFAULT_BRANCH" '
    .default_branch == $branch and
    .allow_merge_commit == true
  ' >/dev/null <<< "$1"
}

verify_hcloud_environment() {
  jq -e --arg maintainer "$RELEASE_MAINTAINER" '
    .can_admins_bypass == false and
    .deployment_branch_policy.protected_branches == false and
    .deployment_branch_policy.custom_branch_policies == true and
    ([.protection_rules[].type] | sort) == (["branch_policy", "required_reviewers"] | sort) and
    ([.protection_rules[] | select(.type == "required_reviewers")] | length) == 1 and
    ([.protection_rules[] | select(.type == "branch_policy")] | length) == 1 and
    ([.protection_rules[] | select(.type == "required_reviewers")][0]) as $review_rule |
    $review_rule.prevent_self_review == false and
    ($review_rule.reviewers | length) == 1 and
    $review_rule.reviewers[0].type == "User" and
    $review_rule.reviewers[0].reviewer.login == $maintainer
  ' >/dev/null <<< "$1"
}

verify_hcloud_environment_policies() {
  jq -e --arg branch "$RELEASE_DEFAULT_BRANCH" '
    .total_count == 1 and
    (.branch_policies | length) == 1 and
    .branch_policies[0].name == $branch and
    .branch_policies[0].type == "branch"
  ' >/dev/null <<< "$1"
}

verify_hcloud_environment_secrets() {
  jq -e '
    .total_count == 1 and
    (.secrets | length) == 1 and
    .secrets[0].name == "HCLOUD_TOKEN"
  ' >/dev/null <<< "$1"
}

fetch_paginated_array() {
  gh api --paginate --slurp "$1" | jq -e '
    if type == "array" and all(.[]; type == "array") then
      add // []
    else
      error("paginated GitHub response was not an array of pages")
    end
  '
}

verify_active_ruleset_inventory() {
  jq -e \
    --arg branch_ruleset "$REQUIRED_BRANCH_RULESET" \
    --arg tag_ruleset "$REQUIRED_TAG_RULESET" \
    --arg repository "$RELEASE_REPOSITORY" '
    ([.[] | select(
      .enforcement == "active" and
      .name == $branch_ruleset and
      .target == "branch" and
      .source_type == "Repository" and
      .source == $repository
    )] | length) == 1 and
    ([.[] | select(
      .enforcement == "active" and
      .name == $tag_ruleset and
      .target == "tag" and
      .source_type == "Repository" and
      .source == $repository
    )] | length) == 1 and
    ([.[] | select(
      .enforcement == "active" and
      .target != "branch" and
      ((
        .name == $tag_ruleset and
        .target == "tag" and
        .source_type == "Repository" and
        .source == $repository
      ) | not)
    )] | length) == 0
  ' >/dev/null <<< "$1"
}

verify_effective_branch_rules() {
  jq -e \
    --argjson ruleset_id "$2" \
    --arg repository "$RELEASE_REPOSITORY" '
    ([.[] | {
      type,
      ruleset_id,
      ruleset_source_type,
      ruleset_source
    }] | sort_by(.type)) ==
    ([
      {type: "deletion", ruleset_id: $ruleset_id, ruleset_source_type: "Repository", ruleset_source: $repository},
      {type: "non_fast_forward", ruleset_id: $ruleset_id, ruleset_source_type: "Repository", ruleset_source: $repository},
      {type: "update", ruleset_id: $ruleset_id, ruleset_source_type: "Repository", ruleset_source: $repository}
    ] | sort_by(.type))
  ' >/dev/null <<< "$1"
}

verify_branch_ruleset() {
  jq -e \
    --arg name "$REQUIRED_BRANCH_RULESET" \
    --arg repository "$RELEASE_REPOSITORY" \
    --arg branch "refs/heads/$RELEASE_DEFAULT_BRANCH" '
    .name == $name and
    .source_type == "Repository" and
    .source == $repository and
    .target == "branch" and
    .enforcement == "active" and
    .conditions.ref_name.include == [$branch] and
    (.conditions.ref_name.exclude // []) == [] and
    ([.rules[].type] | sort) == (["deletion", "non_fast_forward", "update"] | sort) and
    (.bypass_actors | length) == 1 and
    .bypass_actors[0].actor_type == "RepositoryRole" and
    .bypass_actors[0].actor_id == 5 and
    .bypass_actors[0].bypass_mode == "always"
  ' >/dev/null <<< "$1"
}

verify_tag_ruleset() {
  jq -e \
    --arg name "$REQUIRED_TAG_RULESET" \
    --arg repository "$RELEASE_REPOSITORY" '
    .name == $name and
    .source_type == "Repository" and
    .source == $repository and
    .target == "tag" and
    .enforcement == "active" and
    .conditions.ref_name.include == ["refs/tags/v*"] and
    (.conditions.ref_name.exclude // []) == [] and
    ([.rules[].type] | sort) == (["creation", "deletion", "non_fast_forward", "update"] | sort) and
    (.bypass_actors | length) == 1 and
    .bypass_actors[0].actor_type == "RepositoryRole" and
    .bypass_actors[0].actor_id == 5 and
    .bypass_actors[0].bypass_mode == "always"
  ' >/dev/null <<< "$1"
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v gh >/dev/null 2>&1 || { printf 'FAIL: gh is required\n' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'FAIL: jq is required\n' >&2; exit 1; }

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

actual_repository="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
[[ "$actual_repository" == "$RELEASE_REPOSITORY" ]] || fail "release controls must be checked from $RELEASE_REPOSITORY"

repository="$(gh api "repos/$RELEASE_REPOSITORY")"
verify_repository_settings "$repository" || fail "canonical repository must use $RELEASE_DEFAULT_BRANCH and allow merge-commit release integration"

protection="$(gh api "repos/$RELEASE_REPOSITORY/branches/$RELEASE_DEFAULT_BRANCH/protection")"
verify_branch_protection "$protection" || fail "$RELEASE_DEFAULT_BRANCH protection does not enforce the exact merge-commit-compatible PR, review, status, history, lock, signature, restriction, force-push, and deletion controls"

release_owner="${RELEASE_REPOSITORY%%/*}"
release_name="${RELEASE_REPOSITORY#*/}"
# shellcheck disable=SC2016 # GraphQL variables are expanded by GitHub, not the shell.
deployment_protection="$(gh api graphql \
  -f query='query($owner: String!, $name: String!, $branch: String!) {
    repository(owner: $owner, name: $name) {
      ref(qualifiedName: $branch) {
        name
        branchProtectionRule {
          pattern
          requiresDeployments
          requiredDeploymentEnvironments
          bypassPullRequestAllowances(first: 1) {
            totalCount
          }
        }
      }
    }
  }' \
  -F owner="$release_owner" \
  -F name="$release_name" \
  -F branch="refs/heads/$RELEASE_DEFAULT_BRANCH")"
verify_branch_deployment_requirements "$deployment_protection" \
  || fail "$RELEASE_DEFAULT_BRANCH must have one exact branch-protection rule with no required deployments, deployment environments, or pull-request bypass actors"

environment="$(gh api "repos/$RELEASE_REPOSITORY/environments/$HCLOUD_SMOKE_ENVIRONMENT")"
verify_hcloud_environment "$environment" || fail "$HCLOUD_SMOKE_ENVIRONMENT must have exactly one maintainer reviewer and branch-policy rule, no admin bypass, and custom deployment branches"

policies="$(gh api "repos/$RELEASE_REPOSITORY/environments/$HCLOUD_SMOKE_ENVIRONMENT/deployment-branch-policies")"
verify_hcloud_environment_policies "$policies" || fail "$HCLOUD_SMOKE_ENVIRONMENT must allow only $RELEASE_DEFAULT_BRANCH"

secrets="$(gh api "repos/$RELEASE_REPOSITORY/environments/$HCLOUD_SMOKE_ENVIRONMENT/secrets")"
verify_hcloud_environment_secrets "$secrets" || fail "$HCLOUD_SMOKE_ENVIRONMENT must contain only HCLOUD_TOKEN"

rulesets="$(fetch_paginated_array "repos/$RELEASE_REPOSITORY/rulesets?includes_parents=true&per_page=100")"
verify_active_ruleset_inventory "$rulesets" || fail "the complete inherited ruleset catalog must contain the exact release controls and no additional active tag, push, or repository ruleset"

branch_ruleset_id="$(jq -r --arg name "$REQUIRED_BRANCH_RULESET" --arg repository "$RELEASE_REPOSITORY" '[.[] | select(.name == $name and .target == "branch" and .enforcement == "active" and .source_type == "Repository" and .source == $repository)][0].id // empty' <<< "$rulesets")"
[[ -n "$branch_ruleset_id" ]] || fail "the active default-branch update ruleset is required"
branch_ruleset="$(gh api "repos/$RELEASE_REPOSITORY/rulesets/$branch_ruleset_id")"
verify_branch_ruleset "$branch_ruleset" || fail "default-branch ruleset must target only master and allow only the administrator bypass"
effective_branch_rules="$(fetch_paginated_array "repos/$RELEASE_REPOSITORY/rules/branches/$RELEASE_DEFAULT_BRANCH?per_page=100")"
verify_effective_branch_rules "$effective_branch_rules" "$branch_ruleset_id" || fail "effective master rules must come only from the reviewed administrator update ruleset"

tag_ruleset_id="$(jq -r --arg name "$REQUIRED_TAG_RULESET" --arg repository "$RELEASE_REPOSITORY" '[.[] | select(.name == $name and .target == "tag" and .enforcement == "active" and .source_type == "Repository" and .source == $repository)][0].id // empty' <<< "$rulesets")"
[[ -n "$tag_ruleset_id" ]] || fail "the active release-tag ruleset is required"
tag_ruleset="$(gh api "repos/$RELEASE_REPOSITORY/rulesets/$tag_ruleset_id")"
verify_tag_ruleset "$tag_ruleset" || fail "release-tag ruleset must protect every v* tag with only the administrator bypass"

if grep -Eq '^[[:space:]]+workflow_dispatch:' "$repo_root/.github/workflows/publish-release.yaml"; then
  fail "release workflow must be tag-only"
fi

printf 'PASS: exact GitHub release controls protect %s, preserve merge-commit integration, every v* tag, and the %s secret environment.\n' \
  "$RELEASE_DEFAULT_BRANCH" "$HCLOUD_SMOKE_ENVIRONMENT"

#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/check-github-release-controls.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_rejected() {
  local verifier="$1"
  local fixture="$2"
  local label="$3"
  if "$verifier" "$fixture"; then
    fail "$label was accepted"
  fi
}

protection='{
  "enforce_admins":{"enabled":true},
  "required_pull_request_reviews":{
    "required_approving_review_count":0,
    "require_code_owner_reviews":false,
    "require_last_push_approval":false
  },
  "required_status_checks":{"strict":true,"checks":[{"context":"Validate Packer and supply-chain fixtures","app_id":15368}]},
  "required_conversation_resolution":{"enabled":true},
  "allow_force_pushes":{"enabled":false},
  "allow_deletions":{"enabled":false},
  "required_linear_history":{"enabled":false},
  "lock_branch":{"enabled":false},
  "required_signatures":{"enabled":false},
  "restrictions":null
}'
verify_branch_protection "$protection" || fail "safe branch protection was rejected"
expect_rejected verify_branch_protection "$(jq '.enforce_admins.enabled = false' <<< "$protection")" "admin protection drift"
expect_rejected verify_branch_protection "$(jq '.required_status_checks = null' <<< "$protection")" "missing required status check"
expect_rejected verify_branch_protection "$(jq '.required_status_checks.strict = false' <<< "$protection")" "non-strict required status check"
expect_rejected verify_branch_protection "$(jq '.required_status_checks.checks[0].context = "Advisory"' <<< "$protection")" "wrong required status context"
expect_rejected verify_branch_protection "$(jq '.required_status_checks.checks[0].app_id = -1' <<< "$protection")" "unbound required status app"
expect_rejected verify_branch_protection "$(jq '.required_status_checks.checks += [{"context":"Legacy","app_id":15368}]' <<< "$protection")" "additional required status context"
expect_rejected verify_branch_protection "$(jq '.required_linear_history.enabled = true' <<< "$protection")" "linear-history merge deadlock"
expect_rejected verify_branch_protection "$(jq '.lock_branch.enabled = true' <<< "$protection")" "locked-branch merge deadlock"
expect_rejected verify_branch_protection "$(jq '.required_pull_request_reviews.required_approving_review_count = 1' <<< "$protection")" "unavailable required approval"
expect_rejected verify_branch_protection "$(jq '.required_pull_request_reviews.require_code_owner_reviews = true' <<< "$protection")" "unavailable code-owner approval"
expect_rejected verify_branch_protection "$(jq '.required_pull_request_reviews.require_last_push_approval = true' <<< "$protection")" "unavailable last-push approval"
expect_rejected verify_branch_protection "$(jq '.required_signatures.enabled = true' <<< "$protection")" "signature-only branch drift"
expect_rejected verify_branch_protection "$(jq '.restrictions = {users:[],teams:[],apps:[]}' <<< "$protection")" "push restriction drift"

deployment_protection='{
  "data":{"repository":{"ref":{
    "name":"master",
    "branchProtectionRule":{
      "pattern":"master",
      "requiresDeployments":false,
      "requiredDeploymentEnvironments":[],
      "bypassPullRequestAllowances":{"totalCount":0}
    }
  }}}
}'
verify_branch_deployment_requirements "$deployment_protection" \
  || fail "safe GraphQL deployment protection was rejected"
expect_rejected verify_branch_deployment_requirements "$(jq '.data.repository.ref.branchProtectionRule.requiresDeployments = true' <<< "$deployment_protection")" "required deployment drift"
expect_rejected verify_branch_deployment_requirements "$(jq '.data.repository.ref.branchProtectionRule.requiredDeploymentEnvironments = ["production"]' <<< "$deployment_protection")" "required deployment environment drift"
expect_rejected verify_branch_deployment_requirements "$(jq '.data.repository.ref.branchProtectionRule.bypassPullRequestAllowances.totalCount = 1' <<< "$deployment_protection")" "pull-request bypass actor drift"
expect_rejected verify_branch_deployment_requirements "$(jq 'del(.data.repository.ref.branchProtectionRule.bypassPullRequestAllowances)' <<< "$deployment_protection")" "missing pull-request bypass authority"
expect_rejected verify_branch_deployment_requirements "$(jq '.data.repository.ref.branchProtectionRule.bypassPullRequestAllowances = null' <<< "$deployment_protection")" "null pull-request bypass authority"
expect_rejected verify_branch_deployment_requirements "$(jq '.data.repository.ref.branchProtectionRule.bypassPullRequestAllowances.totalCount = "0"' <<< "$deployment_protection")" "malformed pull-request bypass count"
expect_rejected verify_branch_deployment_requirements "$(jq '.data.repository.ref.branchProtectionRule = null' <<< "$deployment_protection")" "missing authoritative branch-protection rule"
expect_rejected verify_branch_deployment_requirements "$(jq '.data.repository.ref.branchProtectionRule.pattern = "release/*"' <<< "$deployment_protection")" "ambiguous branch-protection pattern"

repository='{"default_branch":"master","allow_merge_commit":true}'
verify_repository_settings "$repository" || fail "safe repository settings were rejected"
expect_rejected verify_repository_settings "$(jq '.allow_merge_commit = false' <<< "$repository")" "disabled merge-commit integration"
expect_rejected verify_repository_settings "$(jq '.default_branch = "main"' <<< "$repository")" "wrong default branch"

environment='{
  "can_admins_bypass":false,
  "deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true},
  "protection_rules":[{
    "type":"required_reviewers",
    "prevent_self_review":false,
    "reviewers":[{"type":"User","reviewer":{"login":"mysticaltech"}}]
  },{"type":"branch_policy"}]
}'
verify_hcloud_environment "$environment" || fail "safe HCloud environment was rejected"
expect_rejected verify_hcloud_environment "$(jq '.protection_rules[0].reviewers += [{"type":"User","reviewer":{"login":"attacker"}}]' <<< "$environment")" "additional environment reviewer"
expect_rejected verify_hcloud_environment "$(jq '.can_admins_bypass = true' <<< "$environment")" "environment admin bypass"
expect_rejected verify_hcloud_environment "$(jq '.protection_rules += [{"type":"wait_timer","wait_timer":0}]' <<< "$environment")" "additional environment protection rule"

policies='{"total_count":1,"branch_policies":[{"name":"master","type":"branch"}]}'
verify_hcloud_environment_policies "$policies" || fail "safe deployment policy was rejected"
expect_rejected verify_hcloud_environment_policies "$(jq '.branch_policies += [{"name":"release/*","type":"branch"}] | .total_count = 2' <<< "$policies")" "additional deployment branch"

secrets='{"total_count":1,"secrets":[{"name":"HCLOUD_TOKEN"}]}'
verify_hcloud_environment_secrets "$secrets" || fail "expected HCloud secret was rejected"
expect_rejected verify_hcloud_environment_secrets "$(jq '.secrets += [{"name":"SECOND_TOKEN"}] | .total_count = 2' <<< "$secrets")" "additional environment secret"

# shellcheck disable=SC2329 # Invoked indirectly by fetch_paginated_array.
gh() {
  [[ "$#" == 4 && "$1" == "api" && "$2" == "--paginate" && "$3" == "--slurp" && "$4" == "fixture-pages" ]] || return 1
  printf '%s\n' '[[{"id":1}],[{"id":2}]]'
}
paginated_fixture="$(fetch_paginated_array fixture-pages)"
jq -e 'map(.id) == [1, 2]' >/dev/null <<< "$paginated_fixture" \
  || fail "paginated GitHub arrays were not completely flattened"
unset -f gh

rulesets='[
  {"id":1,"name":"Restrict master updates to administrators","target":"branch","enforcement":"active","source_type":"Repository","source":"mysticaltech/terraform-hcloud-kube-hetzner"},
  {"id":2,"name":"Protect v release tags","target":"tag","enforcement":"active","source_type":"Repository","source":"mysticaltech/terraform-hcloud-kube-hetzner"}
]'
verify_active_ruleset_inventory "$rulesets" || fail "safe active ruleset inventory was rejected"
verify_active_ruleset_inventory "$(jq '. += [{"id":3,"name":"Protect develop","target":"branch","enforcement":"active","source_type":"Organization","source":"mysticaltech"}]' <<< "$rulesets")" \
  || fail "unrelated active branch ruleset was incorrectly rejected before effective-rule evaluation"
expect_rejected verify_active_ruleset_inventory "$(jq '. += [{"id":4,"name":"Additional tag policy","target":"tag","enforcement":"active","source_type":"Organization","source":"mysticaltech"}]' <<< "$rulesets")" "additional active tag ruleset"
expect_rejected verify_active_ruleset_inventory "$(jq '.[0].target = "tag"' <<< "$rulesets")" "wrong active ruleset target"
verify_active_ruleset_inventory "$(jq '. += [{"id":5,"name":"Draft future policy","target":"branch","enforcement":"disabled","source_type":"Organization","source":"mysticaltech"}]' <<< "$rulesets")" \
  || fail "inactive ruleset incorrectly changed live merge availability"

branch_ruleset='{
  "name":"Restrict master updates to administrators",
  "source_type":"Repository",
  "source":"mysticaltech/terraform-hcloud-kube-hetzner",
  "target":"branch",
  "enforcement":"active",
  "conditions":{"ref_name":{"include":["refs/heads/master"],"exclude":[]}},
  "rules":[{"type":"update"},{"type":"deletion"},{"type":"non_fast_forward"}],
  "bypass_actors":[{"actor_type":"RepositoryRole","actor_id":5,"bypass_mode":"always"}]
}'
verify_branch_ruleset "$branch_ruleset" || fail "safe branch ruleset was rejected"
expect_rejected verify_branch_ruleset "$(jq '.conditions.ref_name.exclude = ["refs/heads/master"]' <<< "$branch_ruleset")" "default-branch exclusion"
expect_rejected verify_branch_ruleset "$(jq '.bypass_actors += [{"actor_type":"RepositoryRole","actor_id":4,"bypass_mode":"always"}]' <<< "$branch_ruleset")" "additional branch bypass actor"
expect_rejected verify_branch_ruleset "$(jq '.rules |= map(select(.type != "deletion"))' <<< "$branch_ruleset")" "missing branch deletion rule"

effective_branch_rules='[
  {"type":"update","ruleset_id":1,"ruleset_source_type":"Repository","ruleset_source":"mysticaltech/terraform-hcloud-kube-hetzner"},
  {"type":"deletion","ruleset_id":1,"ruleset_source_type":"Repository","ruleset_source":"mysticaltech/terraform-hcloud-kube-hetzner"},
  {"type":"non_fast_forward","ruleset_id":1,"ruleset_source_type":"Repository","ruleset_source":"mysticaltech/terraform-hcloud-kube-hetzner"}
]'
verify_effective_branch_rules "$effective_branch_rules" 1 || fail "safe effective master rules were rejected"
if verify_effective_branch_rules "$(jq '. += [{"type":"required_linear_history","ruleset_id":3,"ruleset_source_type":"Organization","ruleset_source":"mysticaltech"}]' <<< "$effective_branch_rules")" 1; then
  fail "additional inherited master rule was accepted"
fi

tag_ruleset='{
  "name":"Protect v release tags",
  "source_type":"Repository",
  "source":"mysticaltech/terraform-hcloud-kube-hetzner",
  "target":"tag",
  "enforcement":"active",
  "conditions":{"ref_name":{"include":["refs/tags/v*"],"exclude":[]}},
  "rules":[{"type":"creation"},{"type":"update"},{"type":"deletion"},{"type":"non_fast_forward"}],
  "bypass_actors":[{"actor_type":"RepositoryRole","actor_id":5,"bypass_mode":"always"}]
}'
verify_tag_ruleset "$tag_ruleset" || fail "safe tag ruleset was rejected"
expect_rejected verify_tag_ruleset "$(jq '.conditions.ref_name.exclude = ["refs/tags/v3.1.0"]' <<< "$tag_ruleset")" "release-tag exclusion"
expect_rejected verify_tag_ruleset "$(jq '.bypass_actors += [{"actor_type":"RepositoryRole","actor_id":4,"bypass_mode":"always"}]' <<< "$tag_ruleset")" "additional tag bypass actor"
expect_rejected verify_tag_ruleset "$(jq '.rules |= map(select(.type != "creation"))' <<< "$tag_ruleset")" "missing tag creation rule"

printf 'PASS: release-control predicates reject exclusions, extra principals, extra secrets, and incomplete rules.\n'

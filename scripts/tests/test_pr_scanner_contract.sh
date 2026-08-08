#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow="$repo_root/.github/workflows/lint_pr.yaml"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

scanner_job="$(awk '
  /^  tfsec:$/ { capture = 1 }
  capture && /^  [A-Za-z0-9_-]+:$/ && $0 != "  tfsec:" { exit }
  capture { print }
' "$workflow")"

[[ -n "$scanner_job" ]] || fail "tfsec job is missing"
grep -Fq 'contents: read' <<< "$scanner_job" || fail "scanner job must be contents-read only"
if grep -Eq 'pull-requests:[[:space:]]*write|github[.]token|secrets[.]|reviewdog/action-tfsec|tfsec_version:[[:space:]]*latest|/latest/' <<< "$scanner_job"; then
  fail "scanner job must not receive write tokens, secrets, reviewdog, or mutable versions"
fi
grep -Fq 'TFSEC_VERSION: 1.28.14' <<< "$scanner_job" || fail "tfsec version is not pinned"
grep -Fq 'TFSEC_SHA256: 329ae7f67f2f1813ebe08de498719ea7003c75d3ca24bb0b038369062508008e' <<< "$scanner_job" \
  || fail "tfsec archive digest is not independently pinned"
grep -Fq -- "--proto '=https' --proto-redir '=https' --tlsv1.2" <<< "$scanner_job" \
  || fail "tfsec download must require HTTPS/TLS"
grep -Fq 'sha256sum -c -' <<< "$scanner_job" || fail "tfsec archive must be verified before extraction"
grep -Fq 'tfsec --ignore-hcl-errors .' <<< "$scanner_job" || fail "verified scanner is not executed"

printf 'PASS: PR tfsec scanning is exact-version, checksummed, and tokenless.\n'

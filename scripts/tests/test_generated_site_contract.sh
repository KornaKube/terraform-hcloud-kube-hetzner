#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
site_index="$repo_root/site-docs/index.md"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

python3 "$repo_root/scripts/sync_docs_site.py" --check \
  || fail "checked-in site documentation does not match its sources"

if rg -n \
  'raw[.]githubusercontent[.]com/(kube-hetzner|mysticaltech)/terraform-hcloud-kube-hetzner/(master|main)/(scripts/create[.]sh|kube[.]tf[.]example|packer-template/)' \
  "$repo_root/site-docs"; then
  fail "generated site exposes a moving raw setup or Packer bootstrap"
fi

if rg -n '__KH_SOURCE_|__KH_PACKER_BUNDLE_' "$site_index"; then
  fail "moving site copied release-specific bootstrap placeholders"
fi
grep -Fq 'https://github.com/mysticaltech/terraform-hcloud-kube-hetzner/blob/v3.1.0/README.md#quick-start' "$site_index" \
  || fail "generated quick start does not route to the release-tagged README"
grep -Fq './scripts/install-verified-packer-plugin-hcloud.sh' "$site_index" \
  || fail "generated quick start omits the verified Packer plugin installer"

printf 'PASS: generated site is source-aligned and routes setup through the release-tagged bootstrap.\n'

# Issue #1988: Use stable nodepool keys instead of position-based indices

**Status:** Open
**Labels:** (none)
**Author:** jensens (Jens W. Klein)
**Created:** 2025-12-30

## Problem

Currently, node resource keys include the nodepool's position in the list:

```
format("%s-%s-%s", pool_index, node_key, nodepool_obj.name)
# Results in: "0-0-agent-cax31-fsn1", "1-0-agent-cpx22-fsn1", "2-0-agent-cax31-nbg1"
```

When a nodepool is removed from the middle of the list, all subsequent `pool_index` values shift, causing Terraform to:
1. Destroy all nodes in subsequent pools (keys no longer match)
2. Recreate them with new keys

This also destroys any local storage (Longhorn volumes) on those nodes.

## Current Workaround

Set `count = 0` instead of removing nodepools, and only remove pools from the end of the list. However:
- Easy to miss or forget
- A single `tofu apply` without careful review can cause significant data loss
- Accumulates dead pool definitions over time

## Proposed Solution

Use the nodepool `name` as the stable identifier instead of position:

```hcl
# Current (unstable):
format("%s-%s-%s", pool_index, node_key, nodepool_obj.name)
# "0-0-agent-cax31-fsn1"

# Proposed (stable):
format("%s-%s", nodepool_obj.name, node_key)
# "agent-cax31-fsn1-0"
```

## Implementation Notes

- Requires validation for unique nodepool names
- Breaking change - would require migration guide with `terraform state mv` commands
- Consider opt-in variable or major version bump

## Related

Subnet allocation (`hcloud_network_subnet.agent[N]`) has the same index-based issue.

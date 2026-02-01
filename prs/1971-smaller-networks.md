# PR #1971: feat: Allow for networks smaller than 16 bits

**Status:** Open
**Author:** paulblum00 (Paul Blum)
**Branch:** master -> master
**Created:** 2025-12-01

## Summary

Removes the hardcoding of subnets to at least `/24` size and the amount of subnets to 256. This allows for networks smaller than `/16` to be used.

## Related Issue

Related to #1972

## Implementation Notes

Changes in `agents.tf` and `control_planes.tf` regarding the offset of 101 need clarification. The author couldn't figure out:
- Why the exact offset of 101 exists
- Why not start counting private IPs from the end of the range

The commit introducing the 101 offset is 3 years old.

## Backward Compatibility

Designed to be completely backwards compatible (unless something was overlooked).

## Related

| # | Type | Title | Confidence | Relationship |
|---|------|-------|------------|--------------|
| [#1972](../issues/1972-smaller-network-sizes.md) | Issue | Remove hardcoded network size | 95% | **Implements this request** |
| [#1988](../issues/1988-stable-nodepool-keys.md) | Issue | Stable nodepool keys | 80% | Same component (Network) |
| [#1903](./1903-custom-subnet-ranges.md) | PR | Custom subnet ip ranges | 85% | Same component (Network) |
| [#1867](./1867-lb-ip-selection.md) | PR | LB IP selection | 70% | Same component (Network) |

## Review Notes

- Verify backward compatibility thoroughly
- Understand and document the IP offset logic
- Test with various network sizes

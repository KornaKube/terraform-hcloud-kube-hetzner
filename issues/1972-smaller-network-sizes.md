# Issue #1972: Remove hardcoded network size (allow for IP ranges smaller than 16 bits)

**Status:** Open
**Labels:** (none)
**Author:** paulblum00 (Paul Blum)
**Created:** 2025-12-01

## Problem

The module currently hardcodes:
- Subnet size to be at least 8 bits
- Amount of possible subnets to 256

This effectively hardcodes the network to be `/16` or bigger.

## Use Case

Moving infrastructure from Azure to Hetzner with 16 bits of addresses (`10.34.0.0/16`) reserved. With current module, a single cluster would fill that range. Need at least 3 clusters in different projects, each requiring `10.34.0.0/24` or similar.

## Draft PR

A draft PR exists: #1971

## Related

| # | Type | Title | Confidence | Relationship |
|---|------|-------|------------|--------------|
| [#1971](../prs/1971-smaller-networks.md) | PR | Allow networks smaller than 16 bits | 95% | **Implements this request** |
| [#1988](./1988-stable-nodepool-keys.md) | Issue | Stable nodepool keys | 80% | Same component (Network) |
| [#1985](./1985-multi-region-multi-network.md) | Issue | Multi-region/network support | 75% | Same component (Network) |
| [#1903](../prs/1903-custom-subnet-ranges.md) | PR | Custom subnet ip ranges | 85% | Same component (Network) |
| [#1867](../prs/1867-lb-ip-selection.md) | PR | LB IP selection | 70% | Same component (Network) |

## Backward Compatibility

Changes are designed to be completely backwards compatible.

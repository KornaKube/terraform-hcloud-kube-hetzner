# PR #1903: feat: allow defining custom subnet ip ranges for static agent pools

**Status:** Open
**Author:** pat-s (Patrick Schratz)
**Branch:** feat/subnet_ip_range -> master
**Created:** 2025-09-11

## Summary

Allow defining custom subnet IP ranges for agent pools instead of relying on the default ones incrementing from `10.0.x`.

## Use Case

Useful (and even needed) if certain subnets in this range are already occupied (e.g., by a vswitch connection).

## Implementation

Current approach uses hardcoded logic to increment from 0 (e.g., 10.0, 10.1, 10.2).
New `subnet_ip_range` allows overriding a node pool subnet on an individual basis.

## Review Notes

- Verify no conflicts with existing subnet allocation
- Test with vswitch connections
- Document usage examples

# PR #2008: feat: add swap_size and zram_size support for autoscaler nodepools

**Status:** Open
**Author:** nikolaszimmermann (Nikolas Zimmermann)
**Branch:** nzimmermann/add_swap_support_for_autoscaler_nodepools -> master
**Created:** 2026-01-14

## Summary

Autoscaled nodes can now configure swap space and zRAM using the `swap_size` and `zram_size` parameters, bringing feature parity with control-plane and agent nodepools.

## Implementation

- When `swap_size` is specified, a swap file is created during cloud-init and the node receives the `server-swap` label for scheduling purposes
- When `zram_size` is specified, a zRAM device with zstd compression is configured as swap

## Review Notes

- Verify cloud-init configuration works correctly on autoscaled nodes
- Test swap and zRAM creation
- Check node labels are applied correctly

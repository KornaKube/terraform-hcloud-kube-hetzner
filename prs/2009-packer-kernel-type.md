# PR #2009: feat: add configurable kernel type for packer MicroOS snapshots

**Status:** Open
**Author:** nikolaszimmermann (Nikolas Zimmermann)
**Branch:** nzimmermann/add_support_to_use_lts_kernels -> master
**Created:** 2026-01-14

## Summary

Add a `kernel_type` variable to choose between the rolling release kernel (default) and the longterm LTS kernel. When longterm is selected, the build installs `kernel-longterm` and removes `kernel-default` to ensure GRUB boots the correct kernel.

## Rationale

Kernel 6.18.3-1 led to kernel panics under heavy load on some nodes (cgwb_release trying to release a 0x0 workqueue - null-pointer dereference). Rather than debugging kernel issues, LTS kernels provide more stability for production workloads.

## Review Notes

- Test both kernel types boot correctly
- Verify GRUB configuration is correct
- Check for any compatibility issues with k3s on LTS kernel

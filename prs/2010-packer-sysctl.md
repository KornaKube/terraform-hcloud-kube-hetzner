# PR #2010: feat: add sysctl_config_file variable to packer template

**Status:** Open
**Author:** nikolaszimmermann (Nikolas Zimmermann)
**Branch:** nzimmermann/add_sysctl_tuning_hooks -> master
**Created:** 2026-01-14

## Summary

Allow passing a local file with sysctl settings to be installed into `/etc/sysctl.d/99-custom.conf` during image creation.

## Use Case

Create a file like `sysctl-tweaks.conf`:
```
# OOM prevention for btrfs
vm.min_free_kbytes = 1048576
vm.swappiness = 10
```

Then pass to packer:
```bash
packer build -var "sysctl_config_file=sysctl-tweaks.conf" hcloud-microos-snapshots.pkr.hcl
```

## Implementation

File content is read at plan time using HCL's `file()` function and written to the target via shell commands during provisioning. If no file is specified, no sysctl configuration is applied.

## Review Notes

- Verify file handling edge cases (empty file, invalid path)
- Test sysctl settings persistence after reboot

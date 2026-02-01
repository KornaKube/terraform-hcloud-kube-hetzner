# PR #1936: feat: replace microOS with leapMicro

**Status:** Open
**Author:** pat-s (Patrick Schratz)
**Branch:** feat/leapmicro_support -> master
**Created:** 2025-10-19

## Summary

Major effort to add LeapMicro support as the new default OS, with MicroOS preserved as an option.

## Background

- Initially started in #1628 by @stani-o
- 20-30 packer rebuilds and ~50h of work
- Support for `microos` is preserved

## Key Changes

### SELinux

LeapMicro is much stricter about SELinux. A tailored SELinux policy is applied during cloud-init as a systemd service.

### Usage

Select OS with the `os` variable:
```hcl
{
  name        = "control-plane-fsn1",
  server_type = "cax11",
  location    = "fsn1",
  os          = "leapmicro"  # or "microos"
}
```

## Open Items

- Other CNIs than Cilium
- SELinux issues with rke2-selinux conflicts
- Autoscaler nodes networking issues
- Kubelet reservations may be high for small instances

## Related

| # | Type | Title | Confidence | Relationship |
|---|------|-------|------------|--------------|
| [#1978](../issues/1978-microos-snapshot-robot.md) | Issue | MicroOS snapshot for Robot nodes | 85% | Same component (Packer/OS) |
| [#2011](./2011-packer-timezone.md) | PR | Configurable timezone for packer | 70% | Same component (Packer) |
| [#2010](./2010-packer-sysctl.md) | PR | sysctl_config_file for packer | 70% | Same component (Packer) |
| [#2009](./2009-packer-kernel-type.md) | PR | Configurable kernel type | 70% | Same component (Packer) |

## Review Notes

- Thorough testing required
- Consider migration path for existing clusters
- Document differences between microOS and leapMicro

# Issue #2013: TF often stucks during destruction

**Status:** Open
**Labels:** bug
**Author:** KES777 (Eugen Konkov)
**Created:** 2026-01-19

## Description

When destroying the whole cluster, Terraform gets stuck on:
- `kubernetes_persistent_volume_claim_v1`
- `hcloud_network_subnet.control_plane`

The destruction hangs indefinitely (seen running for 4+ minutes on network subnet).

## Example Output

```
kubernetes_persistent_volume_claim_v1.chatty_backend_data[0]: Still destroying... [00m40s elapsed]
module.k3s.hcloud_network_subnet.control_plane[0]: Still destroying... [id=11849899-10.255.0.0/16, 04m20s elapsed]
```

## Possible Causes

- Resources may have dependencies that prevent clean destruction
- PVC finalizers may be blocking deletion
- Network subnet may have attached resources

## Platform

Linux

# Issue #1978: MicroOS snapshot for Robot nodes

**Status:** Open
**Labels:** (none)
**Author:** knuurr
**Created:** 2025-12-13

## Description

Request to add snapshot creation (e.g., .tar) to packer template for Robot dedicated servers, allowing same OS to be used for robot nodes.

## Current Situation

- Using Ubuntu that Robot offers to install
- Not working with `kured`
- Issues with SELinux and k3s + Cilium

## Benefits

- Unified stack would simplify management
- Same OS across cloud and dedicated servers
- Consistent behavior and tooling

## Request

Add packer template support for Robot-compatible snapshots to enable MicroOS on dedicated servers.

## Related

| # | Type | Title | Confidence | Relationship |
|---|------|-------|------------|--------------|
| [#1936](../prs/1936-leapmicro-support.md) | PR | Replace microOS with leapMicro | 85% | Same component (Packer/OS) |
| [#1916](../prs/1916-robot-server-terraform.md) | PR | Robot server via Terraform | 90% | Same component (Robot) |
| [#2027](./2027-flannel-wireguard-mtu.md) | Issue | Flannel wireguard MTU (Robot+vSwitch) | 75% | Same component (Robot) |
| [#2011](../prs/2011-packer-timezone.md) | PR | Configurable timezone for packer | 70% | Same component (Packer) |
| [#2009](../prs/2009-packer-kernel-type.md) | PR | Configurable kernel type | 70% | Same component (Packer) |

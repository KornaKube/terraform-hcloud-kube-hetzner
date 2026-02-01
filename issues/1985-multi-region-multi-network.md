# Issue #1985: Support for mixing regions and private networks

**Status:** Open
**Labels:** (none)
**Author:** knuurr
**Created:** 2025-12-23

## Problem

1. Hetzner limits to max 100 servers TOTAL in a private network, making it impossible to create large clusters
2. Nodes from outside the network zone (e.g., US-based node in EU cluster) can't communicate via private IP

## Proposal

Allow specifying multiple private networks for scheduling nodes:
- Networks created on-demand by kube-hetzner
- Pre-created externally
- List of networks managed under kube-hetzner

For external nodes:
- Overlay network would need to be enforced
- Public control plane LB IP used for node joining
- `external = true` flag in node pool definition

## Open Questions

- How would cluster autoscaler handle multiple private networks?
- Would need awareness of when limit is hit
- Preference list for which networks to prioritize

## Use Cases

- Large scale clusters (100+ nodes)
- Multi-region deployments
- Mixed cloud/dedicated server environments

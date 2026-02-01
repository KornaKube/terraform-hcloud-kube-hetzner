# PR #1784: Add RKE2 as an additional kubernetes distribution

**Status:** Open
**Author:** mikeywuu (Mike)
**Branch:** add-rke2-wip -> master
**Created:** 2025-06-09

## Summary

Major PR to enable deployment of Kubernetes clusters with RKE2 instead of k3s.

## New Variables

- `kubernetes_distribution_type` - switch between "k3s" and "rke2"
- `install_rke2_version` - defaults to current stable version

## Current Limitations

- Only Cilium CNI tested
- SELinux not working (disabled for testing)
- Autoscaled nodes have networking issues (no logs, no exec, no metrics)
- Kubelet reservations may be too high for small instances (cax11)

## Open Items

- [ ] Other CNIs than Cilium
- [ ] SELinux support
- [ ] Autoscaler networking
- [ ] Documentation updates

## Review Notes

- Large change, needs thorough review
- May want to split into smaller PRs
- Significant testing required before merge

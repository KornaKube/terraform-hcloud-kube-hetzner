# PR #1911: add control_plane_endpoint variable for external load balancer

**Status:** Open
**Author:** AdoPi (Adonis)
**Branch:** master -> master
**Created:** 2025-09-18

## Summary

In some setups using an external load balancer (e.g., HAProxy), agents and secondary control planes could connect to the cluster through a stable endpoint instead of directly using one of the control plane nodes.

When using `enable_klipper_metal_lb = true`, it's useful to force setting a URL for the external load balancer.

## New Variable

```hcl
control_plane_endpoint = "https://haproxy.mydomain.com:6443"
```

## Review Notes

- Verify compatibility with various LB configurations
- Test failover scenarios
- Document use cases clearly

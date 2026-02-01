# PR #1867: Select IP for hcloud_load_balancer_network based on last ip in subnet

**Status:** Open
**Author:** edhar-rybak (Edhar Rybak)
**Branch:** small-cidrs -> master
**Created:** 2025-08-10

## Problem

With `network_ipv4_cidr = "10.207.128.0/17"`, IP allocation fails for x.x.x.0/25 networks because:

```hcl
network_ipv4_subnets = [for index in range(256) : cidrsubnet(var.network_ipv4_cidr, 8, index)]
```

## Solution

Change logic to select last IP address for `hcloud_load_balancer_network` regardless of the subnet size.

## Review Notes

- Verify this doesn't break existing deployments
- Test with various CIDR sizes
- Check load balancer connectivity after change

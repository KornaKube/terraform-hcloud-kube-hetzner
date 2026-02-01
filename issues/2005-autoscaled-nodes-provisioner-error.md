# Issue #2005: Issue with terraform when autoscaled instance does not exist anymore

**Status:** Open
**Labels:** bug
**Author:** KES777 (Eugen Konkov)
**Created:** 2026-01-14

## Description

When an autoscaled instance no longer exists, Terraform errors during provisioning:

```
Error: file provisioner error

  with module.k3s.null_resource.autoscaled_nodes_registries["chatty-autoscaled-ash-13922888c410fd00"],
  on autoscaler-agents.tf line 203

timeout - last error: dial tcp 10.255.0.1XX: connect: network is unreachable
```

Also, control plane server creation times out waiting for MicroOS to become available.

## Configuration

- 1 control plane
- 0 agent nodes
- 1 autoscale instance
- `autoscaler_disable_ipv4 = true`
- `autoscaler_disable_ipv6 = true`

## Side Note

When cluster destruction fails due to protected volume, Terraform tries to connect to the already destroyed kube cluster using still existing kubeconfig.

## Platform

Linux

# Issue #1984: Can't reconcile network-related changes with kube.tf

**Status:** Open
**Labels:** bug
**Author:** asemarian (Asem Zletni)
**Created:** 2025-12-23

## Description

After upgrading from v1.2.0 to v2.18.4, a failed apply (caused by placement group capacity limits) left the cluster unreachable due to inconsistent private IP assignments. Cluster was recovered by manually updating node IPs in `/etc/rancher/k3s/config.yaml`.

## Current Problem

`terraform plan` consistently shows destructive update in-place for two agent nodes:

```
# module.kube-hetzner.module.agents["8-0-agent-nbg1-16gb-cpx41"].hcloud_server.server will be updated in-place
  ~ resource "hcloud_server" "server" {
      - network {
          - ip = "10.255.0.7" -> null
        }
      + network {
          + ip = "10.8.0.101"
        }
    }
```

## Additional Issues

- Autoscaled nodes failing to join cluster
- Network configuration update cannot be done via kube.tf

## Help Needed

How to update the network configuration when kube.tf doesn't offer an option for that?

## Platform

Linux

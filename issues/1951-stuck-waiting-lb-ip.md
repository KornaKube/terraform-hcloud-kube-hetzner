# Issue #1951: Provisioning a cluster gets stuck on Waiting for load-balancer to get an IP

**Status:** Open
**Labels:** bug
**Author:** victorlane (Victor)
**Created:** 2025-11-08

## Description

Provisioning a new cluster sends terraform into a "Waiting for load-balancer to get an IP..." loop. It eventually times out, persistently failing on specific worker servers.

## Error

```
Error: remote-exec provisioner error
  with module.kube-hetzner.null_resource.agents["2-0-worker-hel-cx33"]
error executing "/tmp/terraform_...sh": Process exited with status 124

Error: remote-exec provisioner error
  with module.kube-hetzner.null_resource.kustomization
error executing "/tmp/terraform_...sh": Process exited with status 124
```

## Observations

- Was able to roll out clusters fine a couple of days ago with same configuration
- Other nodes (control planes, database) join cluster fine
- Re-applying failed kustomizations doesn't help

## Configuration

- 3 control planes across nbg1, hel1, fsn1
- Worker nodes in fsn1, hel1
- enable_wireguard = true
- cni_plugin = "cilium"
- ingress_controller = "nginx"

## Platform

MacOS Tahoe 26.1

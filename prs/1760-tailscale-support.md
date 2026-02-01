# PR #1760: Add Tailscale support

**Status:** Open
**Author:** MarekPikula (Marek Pikula)
**Branch:** tailscale -> master
**Created:** 2025-06-05

## Summary

Introduces support for enabling Tailscale on cluster nodes.

## Benefits

1. Secure, private connection to all nodes without jump host
2. Route private IP of control plane LB using Tailscale subnet router for HA access to K3s socket
3. Allows disabling public interface on LB without needing jump host
4. Constrains firewall to disable SSH and K3s socket access on public interfaces

## Use Case

Compromise between public and fully private cluster (as proposed in #1681), which would otherwise require a bastion host - adding cost and complexity while reducing HA scope.

## Features

- Can be dynamically enabled/disabled on existing deployment
- Subnet router support for private LB access
- Firewall integration

## Review Notes

- Security implications of Tailscale integration
- Verify dynamic enable/disable works correctly
- Test with various network configurations

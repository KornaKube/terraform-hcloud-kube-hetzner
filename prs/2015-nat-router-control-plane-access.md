# PR #2015: Use NAT-router for control plane access too

**Status:** Open
**Author:** sjoerdmulder (Sjoerd Mulder)
**Branch:** nat-router-for-control-plane-access -> master
**Created:** 2026-01-20

## Summary

Enables external kubectl access when using `control_plane_lb_enable_public_interface = false` by automatically forwarding port 6443 on the NAT router to the control plane LB's private IP.

## Changes

- **NAT Router**: Automatically configures iptables DNAT/MASQUERADE rules when control plane LB has no public interface
- **Kubeconfig**: Uses NAT router's public IP as server address when CP LB is private-only
- **TLS Certificates**: Adds NAT router IP to K3s API server certificate SANs
- **Documentation**: Updated README, llms.md, and variable descriptions

## Use Case

Allows restricting access to the control plane APIs using Hetzner Firewall while still allowing external kubectl access via NAT router.

## Review Notes

- Security implications of routing API traffic through NAT router
- Certificate validation with new SANs
- Firewall rule testing

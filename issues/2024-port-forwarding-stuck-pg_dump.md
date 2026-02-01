# Issue #2024: port-forwarding connection gets stuck while doing pg_dump

**Status:** Open
**Labels:** bug
**Author:** radnov
**Created:** 2026-01-28

## Description

When executing a `pg_dump` command from a local machine, targeting a Postgres DB pod in a K3s cluster running on Hetzner (deployed via this project) through a port-forward, the connection gets stuck randomly.

## Steps to Reproduce

1. Deploy a k3s cluster on Hetzner via this project
2. Deploy a Postgres DB pod
3. Create a port-forward: `kubectl -n dev port-forward svc/test-05-database-postgresql 41637:5432`
4. Execute pg_dump command - connection gets stuck

## Key Observations

- Port appears open (nc -vz localhost shows open)
- Postgres stuck on `ClientRead`
- Issue NOT reproducible with manually installed k3s cluster (same version via get.k3s.io) on AWS EC2

## Configuration

- 3 control plane nodes (ccx13)
- Autoscaler nodepools (ccx33)
- lb11 load balancer
- nginx ingress controller
- hetzner_ccm_use_helm = true

## Platform

Linux

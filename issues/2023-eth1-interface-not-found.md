# Issue #2023: k3s Error: unable to find interface eth1

**Status:** Open
**Labels:** bug
**Author:** MaximilianMeister (Maximilian Meister)
**Created:** 2026-01-27

## Description

After upgrading from `2.17.4` to `2.18.5`, one control plane node went down. The k3s.service was in a crash loop with:

```
Error: unable to find interface eth1: route ip+net: no such network interface
```

## Root Cause

The missing `eth1` interface could be fixed by running `/etc/cloud/rename_interface.sh` manually. This script appears to run only once on installation, so a reboot of the broken control-plane didn't help.

## Questions

- What caused this during upgrade?
- Is it required (and safe) to run `/etc/cloud/rename_interface.sh` again on all other nodes?

## Impact

On all other nodes (control-plane/agents) there is also no `eth1` but k3s.service and k3s-agent.service are still running. If services restart or machines reboot, they may show the same error.

## Platform

Linux

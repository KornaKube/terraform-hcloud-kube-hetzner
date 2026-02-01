# PR #1916: Hetzner Robot dedicated server usage via Terraform-scripts, update instructions

**Status:** Open
**Author:** vsalomaki
**Branch:** feature/add-robot-template-to-scripts -> master
**Created:** 2025-09-25

## Summary

Adds templates and configuration for connecting Cluster to Robot Nodes based on the add-robot-server.md instructions.

## Problem

When starting a new cluster, the HCCM configuration with `robot.enabled = true` gives errors as ROBOT_USER and ROBOT_PASSWORD are required.

## Solution

Add Robot Webservice user and password handling similar to hcloud_token.

## New Variables

- `robot_user` (string, sensitive)
- `robot_password` (string, sensitive)
- `robot_ccm_enabled` (bool)
- `vswitch_subnet_index` (number)
- `vswitch_id` (number, nullable)

## Changes

- HCCM secret now includes robot-user and robot-password
- CSI pods prevented from scheduling on robot nodes via nodeAffinity
- vSwitch subnet and route exposure configuration
- Updated documentation in add-robot-server.md

## Test Plan

- [ ] Follow instructions with actual Robot Node
- [ ] Test default configuration without Robot enabled

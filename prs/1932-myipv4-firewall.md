# PR #1932: Add `myipv4` as possible firewall setting input

**Status:** Open
**Author:** vsalomaki
**Branch:** feature/add-myipv4-handling -> master
**Created:** 2025-10-11

## Summary

Add ability to use the string "myipv4" as a source_ip or destination_ip in firewall rules. The current external IP is retrieved using `dig` and replaces the placeholder.

## Implementation

- Uses `external` Terraform provider to run `dig` command
- Supports OpenDNS and Google DNS as fallbacks
- Strict IPv4 address validation
- Only executes if "myipv4" is found in firewall rules

## Usage

```hcl
firewall_ssh_source = ["myipv4"]
```

## New Provider Dependency

`hashicorp/external` provider (~> 2.0)

## Review Notes

- Requires `dig` command to be available
- Security considerations for dynamic IP resolution
- Test failure cases (no internet, dig not installed)

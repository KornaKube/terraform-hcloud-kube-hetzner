# PR #1548: Replace null_resource with terraform_data

**Status:** Open
**Author:** janfrederik (Jan Frederik Leger)
**Branch:** feat/null_resource-to-terraform_data -> master
**Created:** 2024-11-15

## Summary

As of Terraform 1.4, the docs suggest using `terraform_data` instead of `null_resource`. See https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource

## Implementation

Uses terraform >= 1.9 `moved` statement to do the refactoring without destroy and recreation of resources.

## Reference

https://registry.terraform.io/providers/hashicorp/null/latest/docs/guides/terraform-migration#migrating-existing-configurations

## Review Notes

- Verify all moved statements are correct
- Test migration path on existing clusters
- Check Terraform version requirements
- Consider impact on users with older Terraform versions

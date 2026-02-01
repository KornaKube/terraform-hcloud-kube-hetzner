# PR #1931: Add test setup for hetzner testing

**Status:** Open
**Author:** vsalomaki
**Branch:** feature/add-hetzner-testing -> master
**Created:** 2025-10-10

## Summary

Add ability to run basic tests in Hetzner. This includes setting up a cluster using kube.tf.example "as-is" and then destroying it.

## Behavior

- Tests don't run if required variables are not defined in GitHub
- Uncertain if it waits for maintainer approval before running

## Review Notes

- Verify approval workflow for external contributors
- Check resource cleanup on failure
- Consider cost implications of automated testing

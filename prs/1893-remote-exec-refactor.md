# PR #1893: refactor: replace `local-exec` for `remote-exec` in hcloud_server.server

**Status:** Open
**Author:** FullmetalBober (Vladyslav Mankivskyi)
**Branch:** master -> master
**Created:** 2025-09-03

## Summary

Replaced `local-exec` with `remote-exec` while keeping the logic - checking if the server is available to connect.

## Motivation

The only thing blocking this module from being compatible with `terraform stacks` is the `local-exec`.

## Review Notes

- Verify remote-exec behavior matches local-exec
- Test in terraform stacks environment
- Check error handling differences

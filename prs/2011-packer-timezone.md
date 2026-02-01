# PR #2011: feat: add configurable timezone for packer MicroOS snapshots

**Status:** Open
**Author:** nikolaszimmermann (Nikolas Zimmermann)
**Branch:** nzimmermann/add_configureable_timezone -> master
**Created:** 2026-01-16

## Summary

Add a timezone variable to set the system timezone on the snapshot. The default is UTC, but can be overridden with any valid timezone identifier (e.g., Europe/Madrid, America/New_York).

## Review Notes

- Verify timezone is properly applied during packer build
- Check that default UTC doesn't break existing behavior
- Test with various timezone identifiers

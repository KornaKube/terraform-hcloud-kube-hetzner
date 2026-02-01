# PR #1924: Add user_kustomizations-map for specifying Kustomization-"sets" to be applied sequentially

**Status:** Open
**Author:** vsalomaki
**Branch:** feature/extra-customize-preinstall-helm -> master
**Created:** 2025-10-04

## Summary

Adds `user_kustomizations` parameter and supporting modules for defining multiple Kustomization sets that are run sequentially.

## Breaking Change

`user_kustomizations` replaces:
- `extra_kustomize_deployment_commands`
- `extra_kustomize_parameters`
- `extra_kustomize_folder`

See `MIGRATION.md` for migration guide.

## Features

- Sequential execution (e.g., install CRD, wait, then install dependent resources)
- Pre and post commands for each set
- Source folder configuration
- Custom parameters per set

## Example

```hcl
user_kustomizations = {
  "1" = {
    source_folder        = "extra-manifests"
    kustomize_parameters = { myvar = "myvalue" }
    pre_commands         = ""
    post_commands        = "kubectl wait --for=condition=Available deployment --all -A --timeout=120s || true"
  }
}
```

## Review Notes

- Breaking change requires thorough testing
- Verify migration path works correctly
- Test sequential execution ordering

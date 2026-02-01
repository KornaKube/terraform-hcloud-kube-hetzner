# PR #1825: Add audit-log feature

**Status:** Open
**Author:** sando38 (Saarko)
**Branch:** audit-log -> master
**Created:** 2025-07-24

## Summary

Enables audit logs on the control plane, similar to the existing kubelet-config PR.

## New Variables

```hcl
k3s_audit_policy_config = <<-EOT
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources: ["pods", "services"]
    namespaces: ["default", "kube-system"]
  - level: Metadata
    omitStages:
      - RequestReceived
  - level: None
    nonResourceURLs:
      - /api*
      - /version
      - /healthz
      - /readyz
EOT

k3s_audit_log_path = "/var/log/k3s-audit/audit.log"
k3s_audit_log_maxage = 30
k3s_audit_log_maxbackup = 10
k3s_audit_log_maxsize = 100  # MB
```

## Testing Notes

- Tested on private IP cluster only
- Tested upgrading an existing control plane
- May trigger unnecessary agent restarts when audit-log changes

## Review Notes

- Verify agent nodes aren't affected by control plane changes
- Test log rotation
- Check disk space implications

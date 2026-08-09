# Security Recipes

Focused workload hardening procedures that preserve the cluster's default security posture.

[Recipe index](../recipes.md) | [SELinux guide](../selinux.md) | [Documentation index](../index.md)

<details>
<summary><strong>Fix SELinux issues with udica</strong></summary>

Create targeted SELinux profiles instead of weakening cluster-wide security:

Policy posture and rule provenance are documented in [`docs/selinux.md`](../selinux.md).

> **Troubleshooting note:** When using large attached volumes (for example large Longhorn disks), first boot can hit cloud-init/systemd timeouts while SELinux relabeling completes. If you hit this repeatedly, a practical workaround is to disable SELinux only on the affected nodepool(s) instead of disabling it cluster-wide.

```sh
# Find container
crictl ps

# Generate inspection
crictl inspect <container-id> > container.json

# Create profile
udica -j container.json myapp --full-network-access

# Install module
semodule -i myapp.cil /usr/share/udica/templates/{base_container.cil,net_container.cil}
```

Apply to deployment:
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: my-container
          securityContext:
            seLinuxOptions:
              type: myapp.process
```

*Thanks @carolosf*
</details>

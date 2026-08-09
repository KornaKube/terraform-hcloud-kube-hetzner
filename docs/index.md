# Documentation

Use this page as the map for kube-hetzner documentation. The README stays focused on what the project is, the shortest path to a running cluster, and where to go next.

## Start and Configure

| Resource | Purpose |
| --- | --- |
| [`README.md`](../README.md) | Four-step installation and the main project overview. |
| [`kube.tf.example`](../kube.tf.example) | Complete example configuration to trim for your cluster. |
| [`terraform.md`](terraform.md) | Generated inputs, outputs, requirements, providers, and resources. |
| [`llms.md`](llms.md) | Detailed operator and assistant reference for variables and topology behavior. |
| [`support-matrix.md`](support-matrix.md) | Supported distributions, network modes, CNIs, and advanced feature maturity. |
| [`../site-docs/`](../site-docs/) | Generated MkDocs overview and configuration-key index. |

## Operate and Recover

| Resource | Purpose |
| --- | --- |
| [`operations.md`](operations.md) | Connecting, access, CNI operations, scaling, HA, dedicated servers, and custom manifests. |
| [`upgrades.md`](upgrades.md) | Module, Kubernetes, and transactional OS upgrade procedures. |
| [`troubleshooting.md`](troubleshooting.md) | Fast health checks, SSH and service diagnosis, and K3s certificate-expiry recovery. |
| [`ssh.md`](ssh.md) | SSH keys, source restrictions, changing operator IPs, and connection behavior. |
| [`backup_restore.md`](backup_restore.md) | Cluster backup and restore guidance. |
| [`customize-mount-path-longhorn.md`](customize-mount-path-longhorn.md) | Longhorn data-path customization. |
| [`selinux.md`](selinux.md) | SELinux policy provenance and the AVC-first troubleshooting workflow. |

## Design and Extend

| Resource | Purpose |
| --- | --- |
| [`v3-topology-recommendations.md`](v3-topology-recommendations.md) | Topology chooser for HA, private-only, Tailscale, multinetwork, Gateway API, and large clusters. |
| [`private-network-egress.md`](private-network-egress.md) | NAT router and private-network egress patterns. |
| [`add-robot-server.md`](add-robot-server.md) | Integrating Hetzner Robot dedicated servers. |
| [`recipes.md`](recipes.md) | Focused configuration recipes for storage, Cilium, Tailscale, snapshots, overlays, and other advanced paths. |
| [`../examples/`](../examples/) | Complete working examples for ArgoCD, Cilium Gateway API, Tailscale, external access, TLS, and user kustomizations. |

## Migrate and Verify

| Resource | Purpose |
| --- | --- |
| [`MIGRATION.md`](../MIGRATION.md) | v2 to v3 compatibility contract, variable map, and production safety model. |
| [`v2-to-v3-migration.md`](v2-to-v3-migration.md) | Step-by-step migration playbook. |
| [`kubernetes-installation-supply-chain.md`](kubernetes-installation-supply-chain.md) | K3s/RKE2 installer and payload verification contract. |
| [`v3-release-evidence.md`](v3-release-evidence.md) | Live deployment, upgrade, health, and teardown evidence behind the current v3 line. |
| [`../tests/README.md`](../tests/README.md) | Local validation gates and live-test expectations. |

## Contribute

Read [`CONTRIBUTING.md`](../CONTRIBUTING.md) before opening a pull request. Repository-native agent workflows live under [`.claude/skills/`](../.claude/skills/).

The files named `v3-*-task-board.md` and the `v3-tailscale-node-transport/` directory are retained as maintainer implementation records. They are historical planning evidence, not operator instructions.

# Images and Runtime Recipes

Build and select transactional OS snapshots, or adapt the runtime for small and remotely executed deployments.

[Recipe index](../recipes.md) | [Documentation index](../index.md)

<details>
<summary><strong>Managing snapshots</strong></summary>

**Create (recommended):**
```sh
export HCLOUD_TOKEN=<your-token>
cd /path/to/generated/project/packer
./scripts/install-verified-packer-plugin-hcloud.sh
for distro in k3s rke2; do
  packer build -var "selinux_package_to_install=${distro}" hcloud-leapmicro-snapshots.pkr.hcl
done
```

Leap Micro snapshot descriptions include a UTC timestamp and collision-resistant build ID, so this command can refresh images without deleting snapshots still used by running nodes. The module selects the newest matching OS, architecture, and Kubernetes distribution for new nodes unless you pin a snapshot ID.

The default build accepts only the exact version-bound `download.opensuse.org` `Default-qcow` endpoint. Before writing the image, it verifies the publisher-signed checksum against the vendored openSUSE full-fingerprint trust anchor, rejects expired/revoked keys and signatures, binds the signed filename to the requested version, architecture, and flavor, and compares it with the reviewed exact-byte digest bundled for the selected version. Rancher SELinux RPMs are bound to the exact repository, release tag, filename, full signing-key fingerprint, package identity, and reviewed SHA-256 digest before installation. Trust anchors and artifact digests deliberately fail closed on expiry, rotation, version changes, or upstream refresh; update them only after reviewing the official release and newly signed artifact, then run `scripts/tests/test_packer_trust_anchors.sh` and `scripts/tests/test_leapmicro_verifier.sh`.

Custom mirrors must provide an independently obtained digest in `opensuse_leapmicro_x86_expected_sha256` or `opensuse_leapmicro_arm_expected_sha256`. Adjacent `.sha256` and `.sha256.asc` sidecars are used by default. For query-bearing endpoints, set the corresponding `*_checksum_link` and `*_signature_link` explicitly. Use the architecture-specific sensitive `opensuse_leapmicro_x86_mirror_authorization_header` or `opensuse_leapmicro_arm_mirror_authorization_header` only when that architecture's image and sidecars share one HTTPS origin; authenticated downloads reject redirects, cross-origin URLs, plaintext HTTP, and credentials embedded in URL userinfo.

**Create (legacy MicroOS):**
```sh
export HCLOUD_TOKEN=<your-token>
cd /path/to/generated/project/packer
./scripts/install-verified-packer-plugin-hcloud.sh
for distro in k3s rke2; do
  packer build -var "selinux_package_to_install=${distro}" hcloud-microos-snapshots.pkr.hcl
done
```

MicroOS snapshots also contain one verified, image-baked SELinux policy package and carry a `kube-hetzner/k8s-distro` label. Automatic lookup prefers that matching label and only falls back to an older unlabeled MicroOS snapshot for upgrade compatibility; it never selects an image explicitly labeled for the other distribution.

The default MicroOS build accepts only the exact official rolling ContainerHost OpenStack aliases and requires their publisher-signed checksum to match the reviewed x86/ARM digest in the template. A custom `opensuse_microos_*_mirror_link` requires explicit matching `*_checksum_link`, `*_signature_link`, and `*_expected_sha256` values. Credentials use the architecture-specific sensitive `opensuse_microos_x86_mirror_authorization_header` or `opensuse_microos_arm_mirror_authorization_header`; authenticated downloads require one HTTPS origin and reject redirects, URL userinfo, and cross-origin sidecars.

**Delete:**
```sh
hcloud image list
hcloud image delete <image-id>
```
</details>

<details>
<summary><strong>Custom OS snapshots per nodepool</strong></summary>

Override the default OS snapshot on any nodepool or individual node with `os_snapshot_id`:

```tf
agent_nodepools = [
  {
    name        = "storage",
    server_type = "cx33",
    location    = "nbg1",
    labels      = ["node.kubernetes.io/server-usage=storage"],
    taints      = [],
    count       = 1
    os_snapshot_id = "348644983"  # Custom snapshot with LVM partitions
  },
]
```

Per-node override (in a `nodes` map):
```tf
nodes = {
  "0" : { os_snapshot_id = "348644983" },
  "1" : {},  # uses nodepool or global default
}
```

> **Caution:** You are responsible for ensuring the snapshot ID matches the correct `os` type (`leapmicro`/`microos`) and node architecture (x86 for `cx*`/`cpx*` servers, ARM for `cax*` servers). A mismatched snapshot will cause provisioning failures.

When not set, the module automatically selects the most recent snapshot matching the node's `os`, architecture, and Kubernetes distribution. Legacy unlabeled MicroOS snapshots remain a fallback when no matching distro-labeled MicroOS snapshot exists.
</details>

<details>
<summary><strong>Single-node development cluster</strong></summary>

Set `automatically_upgrade_os = false` (attached volumes don't handle auto-reboots well).

Uses k3s [service load balancer](https://rancher.com/docs/k3s/latest/en/networking/#service-load-balancer) instead of external LB. Ports 80 & 443 open automatically.
</details>

<details>
<summary><strong>Terraform Cloud deployment</strong></summary>

1. Create a Leap Micro snapshot in your project first (or MicroOS if you explicitly use it)
2. Configure SSH keys as Terraform Cloud variables (mark private key as sensitive):

```tf
ssh_public_key  = var.ssh_public_key
ssh_private_key = var.ssh_private_key
```

> **Password-protected keys:** Requires `local` execution mode with your own agent.
</details>

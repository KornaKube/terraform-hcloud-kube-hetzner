# kube-hetzner

> Generated from `README.md` by `scripts/sync_docs_site.py`.

# Kube-Hetzner

### Production-Ready Kubernetes on Hetzner Cloud

**HA by default • Auto-upgrading • Cost-optimized**

A highly optimized, easy-to-use, auto-upgradable Kubernetes cluster powered by k3s on openSUSE Leap Micro (default) / MicroOS (legacy)<br>deployed on [Hetzner Cloud](https://hetzner.com)



---

### Quick Start

<table>
<tr>
<td>1️⃣</td>
<td><strong>Create a Hetzner project</strong> at <a href="https://console.hetzner.cloud/">console.hetzner.cloud</a> and grab an API token (Read & Write)</td>
</tr>
<tr>
<td>2️⃣</td>
<td><strong>Generate an SSH key pair</strong> (passphrase-less ed25519) — or see <a href="docs/ssh.md">SSH options</a></td>
</tr>
<tr>
<td>3️⃣</td>
<td><strong>Run the setup script</strong> — creates your project folder and OS snapshots (Leap Micro recommended):</td>
</tr>
</table>

> The setup bootstrap is cryptographically pinned per release. Run it from the [v3.1.0 release README](https://github.com/mysticaltech/terraform-hcloud-kube-hetzner/blob/v3.1.0/README.md#quick-start); a moving documentation site cannot safely reproduce release-specific pins.

The bootstrap downloads one immutable commit archive and verifies its reviewed
SHA-256 before extracting or executing any release code. It then verifies the
Packer security manifest independently and explicitly overrides any inherited
source-directory setting before running the extracted setup entrypoint. To use
an older release, open that tag's README and run its pinned bootstrap. The Packer
templates, signing keys, verifier scripts, and bundle installer are accepted
only when every file matches the reviewed release manifest, and they are
installed as one transaction. A partial or locally modified old bundle stops
the setup with an explicit error; `kube.tf` remains outside this transaction so
the setup continues to preserve user configuration. The verified generation is
published through one `packer/` directory link only after the whole bundle is
valid, so Packer never sees a half-installed trust bundle.

The downloaded `kube.tf.example` is an exhaustive showcase, not a minimal
starter: it currently defines 3 control-plane pools (3 nodes) and 6 active static
agent pools (7 agent nodes) covering storage, egress, ARM, and node-map examples.
Trim the pools and feature examples you do not need before first apply.

<details>
<summary><strong>Fish shell version</strong></summary>

```fish
bash
# Run the verified bootstrap from the desired release README, then exit back to Fish.
```
</details>

<details>
<summary><strong>Pin a specific release</strong></summary>

Open the desired release tag on GitHub and run the verified bootstrap from that
tag's README. Each release carries its own immutable commit and reviewed archive
and manifest digests; ambient variables cannot select a different source.
</details>

<details>
<summary><strong>What the script does</strong></summary>

```sh
mkdir /path/to/your/new/folder
cd /path/to/your/new/folder
# scripts/create.sh downloads the release commit archive, preserves kube.tf,
# and atomically publishes the verified Packer security bundle under packer/.
export HCLOUD_TOKEN="your_hcloud_token"
cd packer
./scripts/install-verified-packer-plugin-hcloud.sh
packer init hcloud-leapmicro-snapshots.pkr.hcl
for distro in k3s rke2; do
  packer build -var "selinux_package_to_install=${distro}" hcloud-leapmicro-snapshots.pkr.hcl
done
# (optional legacy)
# packer init hcloud-microos-snapshots.pkr.hcl
# for distro in k3s rke2; do
#   packer build -var "selinux_package_to_install=${distro}" hcloud-microos-snapshots.pkr.hcl
# done
hcloud context create <project-name>
```
</details>

<table>
<tr>
<td>4️⃣</td>
<td><strong>Customize your <code>kube.tf</code></strong> — full reference in <a href="docs/terraform.md">terraform.md</a></td>
</tr>
</table>

---

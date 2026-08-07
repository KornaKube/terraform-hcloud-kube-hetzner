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

```sh
tmp_script=$(mktemp) && curl -sSL -o "${tmp_script}" https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/scripts/create.sh && chmod +x "${tmp_script}" && "${tmp_script}" && rm "${tmp_script}"
```

The downloaded `kube.tf.example` is an exhaustive showcase, not a minimal
starter: it currently defines 3 control-plane pools (3 nodes) and 6 active static
agent pools (7 agent nodes) covering storage, egress, ARM, and node-map examples.
Trim the pools and feature examples you do not need before first apply.

<details>
<summary><strong>Fish shell version</strong></summary>

```fish
set tmp_script (mktemp); curl -sSL -o "$tmp_script" https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/scripts/create.sh; chmod +x "$tmp_script"; bash "$tmp_script"; rm "$tmp_script"
```
</details>

<details>
<summary><strong>Save as alias for future use</strong></summary>

```sh
alias createkh='tmp_script=$(mktemp) && curl -sSL -o "${tmp_script}" https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/scripts/create.sh && chmod +x "${tmp_script}" && "${tmp_script}" && rm "${tmp_script}"'
```
</details>

<details>
<summary><strong>What the script does</strong></summary>

```sh
mkdir /path/to/your/new/folder
cd /path/to/your/new/folder
curl -sL https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/kube.tf.example -o kube.tf
curl -sL https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/packer-template/hcloud-leapmicro-snapshots.pkr.hcl -o hcloud-leapmicro-snapshots.pkr.hcl
curl -sL https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/packer-template/hcloud-microos-snapshots.pkr.hcl -o hcloud-microos-snapshots.pkr.hcl
export HCLOUD_TOKEN="your_hcloud_token"
packer init hcloud-leapmicro-snapshots.pkr.hcl
for distro in k3s rke2; do
  packer build -var "selinux_package_to_install=${distro}" hcloud-leapmicro-snapshots.pkr.hcl
done
# (optional legacy)
# packer init hcloud-microos-snapshots.pkr.hcl
# packer build hcloud-microos-snapshots.pkr.hcl
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

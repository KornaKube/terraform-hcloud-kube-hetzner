# kube-hetzner

> Generated from `README.md` by `scripts/sync_docs_site.py`.

# Kube-Hetzner

### Production-ready Kubernetes on Hetzner Cloud

**HA by default | Auto-upgrading | Cost-optimized**


A highly optimized, easy-to-operate Kubernetes cluster powered by k3s or RKE2 on openSUSE Leap Micro, deployed on [Hetzner Cloud](https://hetzner.com).

**Go from an empty Hetzner project to a running cluster in four steps.**



---

## Quick Start

1. Install [OpenTofu](https://opentofu.org/docs/intro/install/) or [Terraform](https://developer.hashicorp.com/terraform/install), [Packer 1.16.0](https://releases.hashicorp.com/packer/1.16.0/), [kubectl](https://kubernetes.io/docs/tasks/tools/), and [hcloud](https://github.com/hetznercloud/cli). With Homebrew, install the other tools in one command:

   ```sh
   brew install opentofu kubectl hcloud
   ```

2. Create a [Hetzner Cloud project](https://console.hetzner.cloud/), create a Read & Write API token, and generate a passphrase-less SSH key (`ssh-keygen -t ed25519`).

3. Run `createkh`. It creates your project folder, `kube.tf`, and the required Leap Micro images.

   Bash/Zsh:

   ```sh
   (tmp_script=$(mktemp) && trap 'rm -f "$tmp_script"' EXIT && curl -fsSL -o "$tmp_script" https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/scripts/create.sh && chmod +x "$tmp_script" && env -u KH_SOURCE_DIRECTORY "$tmp_script")
   ```

   Fish:

   ```fish
   set tmp_script (mktemp); curl -fsSL -o "$tmp_script" https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/scripts/create.sh; and chmod +x "$tmp_script"; and env -u KH_SOURCE_DIRECTORY bash "$tmp_script"; set run_status $status; rm -f "$tmp_script"; test $run_status -eq 0
   ```

4. Edit `kube.tf`, remove example node pools you do not need, then deploy:

   ```sh
   cd <your-project-folder>
   tofu init --upgrade
   tofu plan
   tofu apply
   ```

   Use `terraform` instead of `tofu` if that is what you installed. Every option is listed in the [generated configuration reference](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/blob/master/docs/terraform.md).

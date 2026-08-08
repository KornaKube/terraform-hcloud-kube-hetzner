#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

grep -Fq 'data "hcloud_images" "microos_x86_snapshots"' "$repo_root/data.tf"
grep -Fq 'data "hcloud_images" "microos_arm_snapshots"' "$repo_root/data.tf"
grep -Fq 'with_status       = ["available"]' "$repo_root/data.tf"
grep -Fq 'concat(local.microos_x86_distro_snapshots, local.microos_x86_legacy_snapshots)[0].id' "$repo_root/locals.tf"
grep -Fq 'concat(local.microos_arm_distro_snapshots, local.microos_arm_legacy_snapshots)[0].id' "$repo_root/locals.tf"
grep -Fq 'selected transactional OS snapshot must contain the baked k3s-selinux package and policy' "$repo_root/locals.tf"
grep -Fq 'selected transactional OS snapshot must contain the baked rke2-selinux package and policy' "$repo_root/locals.tf"
if grep -Fq 'data "hcloud_image" "microos_' "$repo_root/data.tf"; then
  echo "FAIL: singleton MicroOS image lookup cannot implement a safe legacy fallback" >&2
  exit 1
fi

cat > "$tmp/main.tf" <<'EOF'
variable "distribution" {
  type = string
}

variable "snapshots" {
  type = list(object({
    id     = number
    labels = map(string)
  }))
}

locals {
  distro_snapshots = [
    for image in var.snapshots : image
    if try(image.labels["kube-hetzner/k8s-distro"], "") == var.distribution
  ]
  legacy_snapshots = [
    for image in var.snapshots : image
    if try(image.labels["kube-hetzner/k8s-distro"], "") == ""
  ]
  selected = try(tostring(concat(local.distro_snapshots, local.legacy_snapshots)[0].id), "")
}
EOF

run_case() {
  local label="$1"
  local expected="$2"
  local snapshots="$3"
  local actual

  actual="$(terraform -chdir="$tmp" console \
    -var='distribution=rke2' \
    -var="snapshots=${snapshots}" <<< 'local.selected')"
  actual="${actual#\"}"
  actual="${actual%\"}"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $label selected '$actual', expected '$expected'" >&2
    exit 1
  fi
  echo "PASS: $label"
}

run_case \
  "matching distro beats a newer wrong-distro image and legacy fallback" \
  "30" \
  '[{id=40,labels={"kube-hetzner/k8s-distro"="k3s"}},{id=30,labels={"kube-hetzner/k8s-distro"="rke2"}},{id=20,labels={}}]'

run_case \
  "newest matching distro image wins" \
  "35" \
  '[{id=35,labels={"kube-hetzner/k8s-distro"="rke2"}},{id=30,labels={"kube-hetzner/k8s-distro"="rke2"}},{id=20,labels={}}]'

run_case \
  "legacy image remains a compatibility fallback" \
  "20" \
  '[{id=40,labels={"kube-hetzner/k8s-distro"="k3s"}},{id=20,labels={}}]'

run_case \
  "wrong-distro images never become fallback candidates" \
  "" \
  '[{id=40,labels={"kube-hetzner/k8s-distro"="k3s"}}]'

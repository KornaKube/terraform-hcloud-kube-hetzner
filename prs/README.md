# Open Pull Requests

This folder contains documentation for all open PRs in the kube-hetzner repository.
Generated: 2026-02-01

**[View Relationships & Review Batches](../issues/RELATIONSHIPS.md)** - See how PRs and issues connect

## Feature PRs (18)

| # | Title | Author | Branch | Created |
|---|-------|--------|--------|---------|
| [2030](./2030-default-k3s-version.md) | Default k3s should be supported | BrammyS | features/default-k3s-version | 2026-02-01 |
| [2029](./2029-k3s-1.35-support.md) | Add support for v1.35.0+k3s1 | BrammyS | features/1.35-support | 2026-02-01 |
| [2025](./2025-autoscaler-config.md) | Configurable Replicas/Resources for Autoscaler | sannysoft | feature/configurable-autoscaler-resources | 2026-01-28 |
| [2015](./2015-nat-router-control-plane-access.md) | Use NAT-router for control plane access | sjoerdmulder | nat-router-for-control-plane-access | 2026-01-20 |
| [2011](./2011-packer-timezone.md) | Configurable timezone for packer MicroOS | nikolaszimmermann | nzimmermann/add_configureable_timezone | 2026-01-16 |
| [2010](./2010-packer-sysctl.md) | sysctl_config_file variable for packer | nikolaszimmermann | nzimmermann/add_sysctl_tuning_hooks | 2026-01-14 |
| [2009](./2009-packer-kernel-type.md) | Configurable kernel type for packer MicroOS | nikolaszimmermann | nzimmermann/add_support_to_use_lts_kernels | 2026-01-14 |
| [2008](./2008-autoscaler-swap-zram.md) | swap_size and zram_size for autoscaler | nikolaszimmermann | nzimmermann/add_swap_support_for_autoscaler_nodepools | 2026-01-14 |
| [1971](./1971-smaller-networks.md) | Allow networks smaller than 16 bits | paulblum00 | master | 2025-12-01 |
| [1936](./1936-leapmicro-support.md) | Replace microOS with leapMicro | pat-s | feat/leapmicro_support | 2025-10-19 |
| [1932](./1932-myipv4-firewall.md) | Add myipv4 as firewall setting | vsalomaki | feature/add-myipv4-handling | 2025-10-11 |
| [1931](./1931-hetzner-testing.md) | Add hetzner testing setup | vsalomaki | feature/add-hetzner-testing | 2025-10-10 |
| [1924](./1924-user-kustomizations.md) | user_kustomizations-map for sequential sets | vsalomaki | feature/extra-customize-preinstall-helm | 2025-10-04 |
| [1916](./1916-robot-server-terraform.md) | Robot dedicated server via Terraform | vsalomaki | feature/add-robot-template-to-scripts | 2025-09-25 |
| [1911](./1911-control-plane-endpoint.md) | control_plane_endpoint for external LB | AdoPi | master | 2025-09-18 |
| [1903](./1903-custom-subnet-ranges.md) | Custom subnet ip ranges for agent pools | pat-s | feat/subnet_ip_range | 2025-09-11 |
| [1825](./1825-audit-log.md) | Add audit-log feature | sando38 | audit-log | 2025-07-24 |
| [1760](./1760-tailscale-support.md) | Add Tailscale support | MarekPikula | tailscale | 2025-06-05 |

## Bug Fix PRs (5)

| # | Title | Author | Branch | Created |
|---|-------|--------|--------|---------|
| [2028](./2028-traefik-values-fix.md) | Upgrade traefik default configuration | markus-seidl | feature/traefik-values-fix | 2026-01-31 |
| [2021](./2021-nat-router-datacenter-fix.md) | Replace deprecated datacenter attribute | elkh510 | master | 2026-01-23 |
| [2016](./2016-lb-exclude-cp-nodes.md) | Exclude cp nodes from ingress lb | k0dard | fix/ingress-lb-targets | 2026-01-20 |
| [2014](./2014-nat-router-disable-root.md) | Disable root on nat-router with sudo | sjoerdmulder | fix/disable-root-when-sudo-enabled | 2026-01-19 |
| [1944](./1944-etcd-curl-port.md) | Fix curl command port for etcd | subseq | patch-1 | 2025-10-27 |

## Refactoring PRs (3)

| # | Title | Author | Branch | Created |
|---|-------|--------|--------|---------|
| [1893](./1893-remote-exec-refactor.md) | Replace local-exec with remote-exec | FullmetalBober | master | 2025-09-03 |
| [1867](./1867-lb-ip-selection.md) | LB IP selection based on last ip | edhar-rybak | small-cidrs | 2025-08-10 |
| [1548](./1548-terraform-data-migration.md) | null_resource to terraform_data | janfrederik | feat/null_resource-to-terraform_data | 2024-11-15 |

## Major Feature PRs (1)

| # | Title | Author | Branch | Created |
|---|-------|--------|--------|---------|
| [1784](./1784-rke2-support.md) | Add RKE2 as kubernetes distribution | mikeywuu | add-rke2-wip | 2025-06-09 |

## Dependency Updates (2)

| # | Title | Author | Created |
|---|-------|--------|---------|
| [2007](./2007-dependabot-fmt-check.md) | Bump terraform-fmt-check 2.2.2 -> 2.2.3 | dependabot | 2026-01-14 |
| [2006](./2006-dependabot-validate.md) | Bump terraform-validate 2.2.2 -> 2.2.3 | dependabot | 2026-01-14 |

## Quick Links

- [GitHub PRs](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/pulls)
- [Ready for Review](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/pulls?q=is%3Apr+is%3Aopen+review%3Arequired)

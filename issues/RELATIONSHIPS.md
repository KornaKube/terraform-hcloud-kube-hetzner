# Issue & PR Relationships

Generated: 2026-02-01
Updated: 2026-02-01 (v2.19.0 minor release merged to master)

---

## Issue Triage by Type

### 🔴 Actual Bugs (Confirmed or Likely)

| # | Title | Evidence | Priority | Has Fix? |
|---|-------|----------|----------|----------|
| [#2023](./2023-eth1-interface-not-found.md) | eth1 interface not found | After upgrade 2.17→2.18 | MEDIUM | Investigate |

### 🟡 Edge Cases (Specific Scenarios)

| # | Title | Scenario | Impact | Action |
|---|-------|----------|--------|--------|
| [#2024](./2024-port-forwarding-stuck-pg_dump.md) | pg_dump port-forward stuck | Large DB dump via port-forward | LOW | Investigate |
| [#2005](./2005-autoscaled-nodes-provisioner-error.md) | Autoscaled node provisioner error | Node deleted mid-provision | LOW | Improve handling |
| [#1951](./1951-stuck-waiting-lb-ip.md) | Stuck waiting for LB IP | Intermittent, specific nodes | MEDIUM | Investigate |
| [#2013](./2013-terraform-stuck-destruction.md) | TF stuck during destruction | PVC finalizers, subnet deps | LOW | Document workaround |
| [#1984](./1984-network-reconciliation-help.md) | Network reconciliation issues | After failed upgrade | LOW | Help user |

### 🔵 Feature Requests (Move to Discussions?)

| # | Title | Request | Complexity | Consider? |
|---|-------|---------|------------|-----------|
| [#1988](./1988-stable-nodepool-keys.md) | Stable nodepool keys | Change resource keying | HIGH | MAJOR release |
| [#1985](./1985-multi-region-multi-network.md) | Multi-region/network | Multiple private networks | VERY HIGH | Future roadmap |
| [#1972](./1972-smaller-network-sizes.md) | Smaller network sizes | Allow <16 bit networks | MEDIUM | Has PR #1971 |
| [#1978](./1978-microos-snapshot-robot.md) | MicroOS for Robot | Packer for dedicated | MEDIUM | Related to #1936 |

### ❓ Needs More Information

| # | Title | Missing | Action |
|---|-------|---------|--------|
| [#2024](./2024-port-forwarding-stuck-pg_dump.md) | pg_dump stuck | Root cause unclear | Ask for network debug |
| [#2023](./2023-eth1-interface-not-found.md) | eth1 not found | Reproduction steps | Ask for full logs |
| [#1951](./1951-stuck-waiting-lb-ip.md) | LB IP stuck | Why specific nodes? | Ask for more details |

---

## Issue Quality Assessment

| # | Version? | kube.tf? | Reproducible? | Quality |
|---|----------|----------|---------------|---------|
| #2024 | ❌ | ✅ | ❓ | Needs version |
| #2023 | ✅ 2.18.5 | ❌ | ❓ | Needs kube.tf |
| #2013 | ❌ | ❌ | ❓ | Poor |
| #2005 | ❌ | ✅ | ✅ | OK |
| #1988 | N/A | N/A | N/A | Feature req |
| #1985 | N/A | N/A | N/A | Feature req |
| #1984 | ✅ 2.18.4 | ✅ | ✅ | **Good** |
| #1978 | N/A | N/A | N/A | Feature req |
| #1972 | N/A | N/A | N/A | Feature req |
| #1951 | ❌ | ✅ | ❓ | Needs version |

---

## Issue Action Summary

### Has PR Ready
- #1972 → #1971 (network size)

### Needs Investigation
- #2023 - eth1 interface (upgrade regression?)
- #2024 - port-forward (network debug needed)
- #1951 - LB IP (intermittent)

### Recently Fixed (v2.19.0 - Minor Release)
- #2027 - Flannel wireguard MTU → Added flannel_backend variable
- #1967 - Upgrade window param → Bumped system-upgrade-controller to v0.18.0
- PRs merged: #2030, #2029, #2025

### Recently Fixed (v2.18.6 - Patch Release)
- #1969 - Traefik v34 breaking changes → Fixed via #2028
- #2019 - NAT router datacenter drift → Fixed via #2021
- #2017 - kured_version null check → Fixed in #2032
- #2002, #2003, #2004 - Documentation fixes

### Move to Discussions
- #1985 - Multi-region (too big for issue, similar to Discussion #282)
- #1988 - Stable keys (needs RFC/design discussion)
- #1978 - MicroOS for Robot (feature request)

### Help User Then Close
- #1984 - Network reconciliation (help with state)
- #2013 - Destruction stuck (document workaround)

---

## PR Triage by Risk Level

### 🔴 High Risk PRs (Deep Security Review Required)

| # | Title | Risk Signals | Action |
|---|-------|--------------|--------|
| [#1784](../prs/1784-rke2-support.md) | Add RKE2 as kubernetes distribution | MASSIVE change, touches everything | MAJOR ONLY |
| [#1936](../prs/1936-leapmicro-support.md) | Replace microOS with leapMicro | OS replacement, SELinux changes | MAJOR ONLY |
| [#1924](../prs/1924-user-kustomizations.md) | user_kustomizations-map | **BREAKING CHANGE** - removes variables | MAJOR ONLY |
| [#1916](../prs/1916-robot-server-terraform.md) | Robot server via Terraform | Adds secrets handling, new infra | Individual review |
| [#1932](../prs/1932-myipv4-firewall.md) | myipv4 firewall setting | External command execution, new provider | Individual review |
| [#2015](../prs/2015-nat-router-control-plane-access.md) | NAT-router control plane access | Security-critical: API access routing | Individual review |

### 🟡 Medium Risk PRs (Careful Review)

| # | Title | Risk Signals | Action |
|---|-------|--------------|--------|
| [#1971](../prs/1971-smaller-networks.md) | Networks smaller than 16 bits | Network architecture, unclear offset logic | Individual review |
| [#1903](../prs/1903-custom-subnet-ranges.md) | Custom subnet ip ranges | Network changes | Individual review |
| [#1867](../prs/1867-lb-ip-selection.md) | LB IP selection | Load balancer changes | Individual review |
| [#1760](../prs/1760-tailscale-support.md) | Tailscale support | Network/security feature | Individual review |
| [#1825](../prs/1825-audit-log.md) | Audit-log feature | Control plane changes | Individual review |
| [#1893](../prs/1893-remote-exec-refactor.md) | local-exec to remote-exec | Provisioner changes | Individual review |
| [#1548](../prs/1548-terraform-data-migration.md) | null_resource to terraform_data | State migration implications | Individual review |

### ✅ Recently Merged (v2.19.0 Minor - 2026-02-01)

| # | Title | Status |
|---|-------|--------|
| #2030 | Default k3s version bump (v1.31 → v1.33) | ✅ Merged to master |
| #2029 | k3s 1.35 support | ✅ Merged to master |
| #2025 | Autoscaler config options | ✅ Merged to master |

### ✅ Recently Merged (v2.18.6 Patch - 2026-02-01)

| # | Title | Status |
|---|-------|--------|
| #2028 | Traefik v34 config fix | ✅ Merged to master |
| #2021 | NAT router datacenter fix | ✅ Merged to master |
| #2032 | kured_version null fix | ✅ Merged to master |

### ✅ Previously Merged (Patch Batch 2026-02-01)

| # | Title | Status |
|---|-------|--------|
| #2016 | Exclude CP from LB | ✅ Merged to master |
| #2014 | Disable root on nat-router | ✅ Merged to master |
| #1944 | Fix etcd curl port | ✅ Merged to master |
| #2007 | Dependabot fmt-check bump | ✅ Merged to master |
| #2006 | Dependabot validate bump | ✅ Merged to master |

### ⚪ Packer-Only PRs (Separate from main module)

| # | Title | Notes |
|---|-------|-------|
| [#2011](../prs/2011-packer-timezone.md) | Packer timezone | Packer template only |
| [#2010](../prs/2010-packer-sysctl.md) | Packer sysctl | Packer template only |
| [#2009](../prs/2009-packer-kernel-type.md) | Packer kernel type | Packer template only |
| [#2008](../prs/2008-autoscaler-swap-zram.md) | Autoscaler swap/zram | Packer + autoscaler |

---

## PR Triage by Release Type

### 🏷️ Minor Release Candidates (Individual Approval Required)

Each needs your decision:

| # | Title | New Feature | Decision Needed |
|---|-------|-------------|-----------------|
| #1911 | control_plane_endpoint | New variable | Want this feature? |
| #2015 | NAT-router CP access | New capability | Security review first |
| #1760 | Tailscale support | New feature | Want this feature? |
| #1825 | Audit-log feature | New feature | Want this feature? |
| #1971 | Smaller networks | Fixes #1972 | Network arch review |

### 🏷️ Major Release Only (DO NOT MIX WITH REGULAR TRIAGE)

These require dedicated focused effort:

| # | Title | Why Major | Effort |
|---|-------|-----------|--------|
| #1784 | **RKE2 support** | Entire new k8s distribution | HUGE |
| #1936 | **LeapMicro support** | OS replacement | LARGE |
| #1924 | **user_kustomizations** | BREAKING: removes old variables | MEDIUM |
| #1548 | **terraform_data migration** | State migration | MEDIUM |

**These get their own release cycle. Don't process with patches/minors.**

---

## Explicit Fix Relationships

PRs that directly fix issues:

| Issue | PR | Status | Release |
|-------|-----|--------|---------|
| #2027 Flannel MTU | flannel_backend var | ✅ Fixed | v2.19.0 |
| #1967 Upgrade window | SUC v0.18.0 | ✅ Fixed | v2.19.0 |
| #1969 Traefik v34 breaking | #2028 | ✅ Merged | v2.18.6 |
| #2019 NAT router datacenter | #2021 | ✅ Merged | v2.18.6 |
| #1972 Smaller networks | #1971 | Needs review | MINOR |

---

## Topic Clusters

### NAT Router (1 item remaining)
| # | Type | Title | Release | Risk |
|---|------|-------|---------|------|
| #2015 | PR | Control plane access via NAT | MINOR | 🟡 |
| ~~#2019~~ | ~~Issue~~ | ~~Infinite replacement cycle~~ | ~~v2.18.6~~ | ✅ Fixed |
| ~~#2021~~ | ~~PR~~ | ~~Fix datacenter attribute~~ | ~~v2.18.6~~ | ✅ Merged |
| ~~#2014~~ | ~~PR~~ | ~~Disable root when sudo~~ | ~~Earlier~~ | ✅ Merged |

### Network Architecture (5 items)
| # | Type | Title | Release | Risk |
|---|------|-------|---------|------|
| #1972 | Issue | Remove hardcoded network size | - | - |
| #1988 | Issue | Stable nodepool keys | - | - |
| #1971 | PR | Smaller networks | MINOR | 🟡 |
| #1903 | PR | Custom subnet ranges | MINOR | 🟡 |
| #1867 | PR | LB IP selection | PATCH | 🟡 |

### Packer/OS (5 items)
| # | Type | Title | Release | Risk |
|---|------|-------|---------|------|
| #1978 | Issue | MicroOS for Robot | - | - |
| #1936 | PR | LeapMicro | **MAJOR** | 🔴 |
| #2011 | PR | Timezone | PATCH | 🟢 |
| #2010 | PR | Sysctl | PATCH | 🟢 |
| #2009 | PR | Kernel type | PATCH | 🟢 |

---

## Needs Investigation (Issues)

| # | Title | Blocker |
|---|-------|---------|
| #2024 | pg_dump port-forward stuck | Unclear root cause |
| #2023 | eth1 interface not found | Needs reproduction |
| #1951 | Stuck waiting for LB IP | Intermittent |
| #2013 | TF stuck during destruction | Needs investigation |
| #2005 | Autoscaled node provisioner error | Complex scenario |

---

## Author Risk Assessment

### Known Contributors (Lower Risk)

| Author | PRs | Notes |
|--------|-----|-------|
| pat-s | #1936, #1903 | Multiple contributions |
| vsalomaki | #1932, #1931, #1924, #1916 | Active contributor |
| nikolaszimmermann | #2011, #2010, #2009, #2008 | Packer focus |
| sjoerdmulder | #2015, #2014 | NAT router work |
| BrammyS | #2030, #2029 | k3s versions (merged v2.19.0) |
| sannysoft | #2025 | Autoscaler config (merged v2.19.0) |
| dependabot | #2007, #2006 | Automated |

---

## Merge Workflow Summary

```
PATCH PRs → staging/patch-batch-YYYYMMDD → Test → master → tag vX.Y.Z
MINOR PRs → pr/NUMBER-desc (individual) → Test → YOUR DECISION → master → tag vX.Y.0
MAJOR PRs → major/desc (separate track) → Focused effort → YOUR DECISION → master → tag vX.0.0
```

**NEVER merge external PRs directly to master.**

---

## Workflow Summary

```
ISSUES:
├── 🔴 BUG (confirmed) → Fix → PR → Staging → Release
├── 🟡 EDGE CASE → Evaluate effort → Fix or document
├── 🟠 USER ERROR → Help user → Improve docs → Close
├── ⚪ OLD VERSION → Ask to upgrade → Close
├── 🔵 FEATURE REQUEST → Move to Discussions
└── ❓ NEEDS INFO → Ask questions → Re-triage

PRs:
├── 🟢 PATCH → Batch staging → Test → master
├── 🟡 MINOR → Individual staging → YOUR DECISION → master
└── 🔴 MAJOR → Separate track → Focused effort → YOUR DECISION
```

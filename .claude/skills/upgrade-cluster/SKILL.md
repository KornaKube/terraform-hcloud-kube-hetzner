---
name: upgrade-cluster
description: Use when upgrading an existing kube-hetzner cluster, including module version bumps, provider lockfile refreshes, K3s channel/version upgrades, system-upgrade-controller changes, or live cluster rollout validation
---

# Upgrade Kube-Hetzner Cluster

Safely upgrade an existing kube-hetzner-managed cluster with Terraform/OpenTofu and Kubernetes runtime proof.

## Use When

- A user asks to upgrade a live kube-hetzner cluster.
- A module version bump must be applied to an existing cluster.
- K3s should move to a newer channel or explicit version.
- Provider/module state must be reconciled without recreating live nodes.
- The user asks whether the cluster is HA before or during an upgrade.

## Hard Rules

- Do not print or commit secrets. Never commit kubeconfigs, `*.tfstate`, `*.tfvars`, local env files, plan files, or `.terraform/`.
- Use the IaC runner already used by the target root. Examples below use `terraform`; substitute `tofu` only if the target root already uses OpenTofu.
- Never let a module refactor recreate live servers, networks, load balancers, volumes, or primary IPs by accident. If a plan shows replacement/destruction, stop and root-cause it.
- Upgrade module convergence and K3s versions as separate phases.
- Upgrade K3s one minor at a time unless the operator has explicit upstream proof that skipping minors is safe for that exact version span.
- Keep final proof concrete: Terraform convergence, node versions, upgrade plans complete, workloads healthy, API ready, ingress/LB healthy, and app readiness healthy.

## Inputs To Establish

- Terraform root path and backend type.
- Current module source/version and target module version/commit.
- Current K3s node versions and target channel/version.
- Kubeconfig/API access path.
- Cluster topology: control-plane count, etcd membership, agent pools, autoscaler pools, ingress/load balancer.
- HA risks: singleton StatefulSets, attached volumes, PodDisruptionBudgets, critical workloads without replicas.
- Health checks: Kubernetes API readiness, ingress/load-balancer health, and at least one application-level readiness URL or command.
- Maintenance constraints and rollback expectations.

## Preflight

```bash
cd <terraform-root>
git status --short --branch
git pull origin <default-branch>

# Confirm local secret/state files are ignored or outside git.
git ls-files | rg '(^|/)(.*kubeconfig.*|.*\.tfstate(\.backup)?|\.terraform/|.*\.tfvars|.*\.auto\.tfvars|\.terraform\.local\.env)$' || true

# Backup state without printing it. Prefer a directory outside the repo.
RUN_DIR="${KUBE_HETZNER_UPGRADE_RUN_DIR:-${TMPDIR:-/tmp}/kube-hetzner-upgrade-$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$RUN_DIR"
terraform state pull > "$RUN_DIR/terraform.tfstate.before.json"

kubectl --kubeconfig <kubeconfig> get nodes -o wide
kubectl --kubeconfig <kubeconfig> get deploy,sts,pdb -A
kubectl --kubeconfig <kubeconfig> get pods -A -o wide
kubectl --kubeconfig <kubeconfig> get --raw='/readyz?verbose'
```

If there are singleton stateful workloads or strict PDBs, decide upgrade behavior before any apply:

- `system_upgrade_use_drain = true`: safer for replicated stateless workloads, but can stall or move singleton stateful workloads.
- `system_upgrade_use_drain = false`: cordons instead of draining; useful when a drain would cause worse downtime or volume attach churn. Existing pods remain until the node service restarts.
- `system_upgrade_enable_eviction = false`: only relevant when draining; can unstick upgrades blocked by PDBs, but may delete pods directly.

## Phase 1: Module Convergence

Update only module/provider settings first. Do not change the K3s channel in the same plan unless unavoidable.

```bash
cd <terraform-root>
terraform init -upgrade -input=false
terraform fmt -check -diff
terraform validate
terraform plan -input=false -parallelism=1 -out=module-upgrade.tfplan
```

Review the plan before applying.

Proceed only if the plan is explainable and does not unexpectedly destroy or replace live infrastructure.

```bash
terraform apply -input=false -parallelism=1 module-upgrade.tfplan
terraform plan -input=false -parallelism=1 -detailed-exitcode
```

If the module changed resource ownership or addresses:

- Back up state again.
- Prefer `terraform import`, `terraform state mv`, or module-supported moved blocks over recreation.
- Migrate one live resource at a time.
- Re-run `terraform plan` after every state operation.
- Do not apply broad plans while state addresses are still ambiguous.

## Phase 2: K3s Upgrade

Determine current and target minors:

```bash
kubectl --kubeconfig <kubeconfig> get nodes -o wide
```

For each minor step:

1. Update `initial_k3s_channel` or `install_k3s_version`.
2. Keep upgrade drain/eviction settings aligned with the HA risk assessment.
3. Plan and apply serially.
4. Wait for system-upgrade plans and nodes.
5. Run runtime checks before proceeding to the next minor.

```bash
terraform fmt -check -diff
terraform validate
terraform plan -input=false -parallelism=1 -out=k3s-<target-minor>.tfplan
terraform apply -input=false -parallelism=1 k3s-<target-minor>.tfplan

kubectl --kubeconfig <kubeconfig> -n system-upgrade get plans,jobs,pods -o wide
kubectl --kubeconfig <kubeconfig> get nodes -o wide
kubectl --kubeconfig <kubeconfig> get deploy,sts -A
kubectl --kubeconfig <kubeconfig> get --raw='/readyz?verbose'
```

Treat these as stop conditions:

- A node is not `Ready`.
- Server or agent upgrade plans are not complete after a reasonable wait.
- Terraform shows unexpected drift.
- Public ingress or application readiness fails repeatedly.
- A singleton stateful workload is stuck on volume attach/detach or unavailable.

## Live Health Checks

Use checks appropriate for the cluster. Examples:

```bash
# API readiness
kubectl --kubeconfig <kubeconfig> get --raw='/readyz?verbose'

# Workload readiness
kubectl --kubeconfig <kubeconfig> get deploy,sts,pods -A -o wide

# Ingress/LB readiness, if hcloud is configured
hcloud load-balancer describe <load-balancer-name>

# Application readiness, if available
for i in 1 2 3 4 5; do
  curl -sS -o /dev/null -w "$i %{http_code}\n" <readiness-url>
  sleep 2
done
```

Old `system-upgrade` pods may show `Unknown` after node restarts while their jobs are `Complete`. Treat that as cleanup noise only if the plans are complete, all nodes are ready, and workloads are healthy.

## Final Report

Report:

- Module version/source before and after.
- K3s version/channel before and after.
- HA assessment: control plane/etcd count, agent pools, ingress replicas, application replicas, and singleton stateful risks.
- Terraform proof: `fmt`, `validate`, final `plan -detailed-exitcode` result.
- Kubernetes proof: node versions, upgrade plans complete, API readyz, deployments/statefulsets ready.
- Ingress/app proof: load balancer target health and application readiness.
- Any incident during the upgrade and the corrective setting or action.
- Remaining risks and the exact condition that would make them safe.

## Git Hygiene

Before committing:

```bash
git status --short
git ls-files | rg '(^|/)(.*kubeconfig.*|.*\.tfstate(\.backup)?|\.terraform/|.*\.tfvars|.*\.auto\.tfvars|\.terraform\.local\.env)$' || true
git diff --cached --check
```

If a secret-bearing local file is tracked, remove it from the index with `git rm --cached <path>`, add an ignore rule, and keep the local file only if it is still operationally needed.

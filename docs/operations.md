# Day-2 Operations

Routine access, scaling, and cluster-management procedures live here. For incident diagnosis, certificate recovery, and broken nodes, use [Troubleshooting](troubleshooting.md).

[Documentation index](index.md)

## Security

### MicroOS / Leap Micro Hardening
- **Immutable base OS:** Leap Micro and MicroOS use transactional updates and read-only system partitions by default, reducing host drift and limiting persistence for unauthorized changes.
- **Reduced host surface:** Cluster nodes are treated as appliance-style Kubernetes hosts; operational changes should flow through Terraform and Kubernetes manifests rather than ad-hoc host mutation.
- **SELinux integration:** The module includes SELinux handling for K3s/RKE2 bootstrap paths, with explicit controls and troubleshooting guidance for strict environments.

### Network Isolation
- **Default deny posture for cluster ingress:** Firewall rules are explicit and can be narrowed to trusted source ranges (`myipv4`/allowlists) for SSH and Kubernetes API exposure.
- **Private cluster topology support:** You can run with private networking and NAT routing patterns to minimize directly exposed node interfaces.
- **Load balancer boundary controls:** Control plane and ingress load balancer exposure can be restricted and combined with firewall source controls to reduce public attack surface.

### RKE2 Security Posture
- **CNCF-conformant distribution option:** RKE2 is supported as a first-class Kubernetes distribution choice in this module.
- **Compliance-oriented operation:** RKE2 is designed for hardened, regulated environments and supports CIS-focused deployment patterns.
- **Certification visibility:** For current security certifications/compliance mappings, reference the upstream RKE2 documentation and release notes as authoritative sources.

## Connecting to the cluster

View cluster details:
```sh
terraform output kubeconfig
terraform output -json kubeconfig | jq
```

### Connect via SSH

```sh
ssh root@<control-plane-ip> -i /path/to/private_key -o StrictHostKeyChecking=no
```

`firewall_ssh_source` defaults to `["0.0.0.0/0", "::/0"]` so initial access is not locked out. Restrict it to `myipv4` or trusted CIDRs as soon as SSH access is proven. For CI/CD runners, include the runner CIDRs. See [SSH docs](ssh.md#firewall-ssh-source-and-changing-ips) for dynamic IP handling.

### Connect via Kube API

```sh
kubectl --kubeconfig clustername_kubeconfig.yaml get nodes
```

Or set it as your default:
```sh
export KUBECONFIG=/<path-to>/clustername_kubeconfig.yaml
```

> **Tip:** If `create_kubeconfig = false`, generate it manually: `terraform output --raw kubeconfig > clustername_kubeconfig.yaml`

---

## CNI Options

Default is **Flannel**. Switch by setting `cni_plugin` to `"calico"` or `"cilium"`.

### Cilium Configuration

Customize via `cilium_values` with [Cilium helm values](https://github.com/cilium/cilium/blob/master/install/kubernetes/cilium/values.yaml).

| Feature | Variable |
|---------|----------|
| Full kube-proxy replacement | `enable_kube_proxy = false` |
| Hubble observability | `cilium_hubble_enabled = true` |

Access Hubble UI:
```sh
kubectl port-forward -n kube-system service/hubble-ui 12000:80
# or with Cilium CLI:
cilium hubble ui
```

---

## Scaling

### Manual Scaling

Adjust `count` in any nodepool and run `terraform apply`. Constraints:

- First control-plane nodepool minimum: **1**
- Drain nodes before removing: `kubectl drain <node-name>`
- Only remove nodepools from the **end** of the list
- Rename nodepools only when count is **0**

**Advanced:** Replace `count` with a `nodes` map for individual node control—see `kube.tf.example`.

### Autoscaling

Enable with `autoscaler_nodepools`. Powered by [Cluster Autoscaler](https://github.com/kubernetes/autoscaler).

> ⚠️ Autoscaled nodes use a snapshot from the initial control plane. Ensure disk sizes match.
> Longhorn storage should stay on static agent nodepools. Autoscaled Longhorn volumes require a write-capable Hetzner token in node user-data and leave detached volumes behind on scale-down.

Cluster Autoscaler will not scale down nodes that run pods with local storage unless explicitly configured to do so. For disposable local data, add `--skip-nodes-with-local-storage=false` to `cluster_autoscaler_extra_args` or annotate individual pods with `cluster-autoscaler.kubernetes.io/safe-to-evict: "true"`.

---

## High Availability

| Control Planes | Recommendation |
|----------------|----------------|
| 3+ (odd numbers) | Full HA with quorum maintenance |
| 2 | Disable auto OS upgrades, manual maintenance |
| 1 | Development only, disable auto upgrades |

See [Rancher's HA documentation](https://rancher.com/docs/k3s/latest/en/installation/ha-embedded/).

---

## Dedicated Servers

Integrate Hetzner Robot servers via [the dedicated server guide](add-robot-server.md).

---

## Adding Extras

Use [Kustomize](https://kustomize.io) for additional deployments:

1. Create a source folder (default: `extra-manifests`) with your `kustomization.yaml.tpl` and manifests.
2. Configure one or more ordered sets with `user_kustomizations`.
3. Each set supports template parameters, optional pre-commands, and post-commands.
4. Sets are applied sequentially with `kubectl apply -k`.

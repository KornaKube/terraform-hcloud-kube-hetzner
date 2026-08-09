# Support Matrix

This is the detailed support and maturity contract for kube-hetzner v3. Use it with the [topology recommendations](v3-topology-recommendations.md) before selecting an advanced network, CNI, or autoscaling path.

[Documentation index](index.md)

## Feature Highlights

<table>
<tr>
<td width="50%" valign="top">

### 🚀 Core Platform
- [x] **Maintenance-free** — Auto-upgrades OS & k3s with rollback
- [x] **Multi-architecture** — Mix x86 and ARM (CAX) for cost savings
- [x] **Private networking** — Secure, low-latency node communication
- [x] **SELinux hardened** — Pre-configured security policies

### 🌐 Networking & CNI
- [x] **CNI flexibility** — Flannel, Calico, or Cilium
- [x] **Cilium XDP** — Hardware-level load balancing
- [x] **Cilium Gateway API** — Native Gateway API controller support
- [x] **WireGuard encryption** — Optional encrypted overlay
- [x] **Dual-stack** — Full IPv4 & IPv6 support
- [x] **Custom subnets** — Define CIDR blocks per nodepool
- [ ] **Cilium multinetwork scale** — Experimental public-overlay preview, not production-supported yet

### ⚖️ Load Balancing
- [x] **Ingress controllers** — Traefik, Nginx, or HAProxy
- [x] **Proxy Protocol** — Preserve client IPs
- [x] **Flexible LB** — Hetzner LB or Klipper

</td>
<td width="50%" valign="top">

### 🔄 High Availability
- [x] **HA showcase topology** — `kube.tf.example` defines 3 control-plane pools + 6 active static agent pools (7 agent nodes)
- [x] **Super-HA** — Span multiple Hetzner locations
- [x] **Cluster autoscaler** — Automatic node scaling
- [x] **Embedded registry mirror** — Opt-in k3s/RKE2 Spegel mirror for trusted large clusters
- [x] **Single-node mode** — Perfect for development

### 💾 Storage
- [x] **Hetzner CSI** — Native block storage with encryption
- [x] **Longhorn** — Distributed storage with replication
- [x] **Custom mount paths** — Configurable storage locations

### 🔒 Security & Operations
- [x] **Audit logging** — Configurable retention policies
- [x] **Firewall rules** — Granular SSH/API access control
- [x] **NAT router** — Fully private clusters
- [x] **Plan-time validation** — Terraform/OpenTofu rejects invalid config combinations early
- [x] **190+ variables** — Fine-tune everything
- [x] **User kustomizations** — Ordered custom manifests with hooks

</td>
</tr>
</table>

---

## v3 Support Levels
| Area | Support level | Notes |
| --- | --- | --- |
| k3s on Leap Micro | Stable default | Recommended path for new clusters. |
| RKE2 on Leap Micro | Supported | Heavier distribution; basic RKE2 preset covered by CI, advanced RKE2 combinations validated manually per release. |
| MicroOS | Legacy/upgrade support | Existing clusters remain supported; new nodepools default to Leap Micro. |
| OpenTofu | Supported | Validate with `tofu init`, `tofu validate`, and `tofu plan` before applying. |
| Addon version defaults | Reviewed deterministic defaults | Unset addon version variables use the module's reviewed version matrix; set `latest` only when you intentionally want upstream latest behavior. |
| Cilium IPv6/dual-stack | Dual-stack static nodes are plan validated; live E2E pending | Preferred advanced CNI path. Static control-plane and agent nodes advertise `node-ip` values matching the configured cluster CIDR families. Standard private-network dual-stack uses Cilium tunnel mode; IPv6-only is rejected on the standard path because direct node-to-node public IPv6 paths are not opened by the module firewall in this release. `nat_router`, `extra_robot_nodes`, and `node_transport_mode = "tailscale"` remain private IPv4-only paths and are rejected with IPv6 cluster CIDRs; active autoscaler nodepools need the experimental public-overlay path until standard autoscaler cloud-init learns runtime IPv6/dual-stack `node-ip` injection. |
| Cilium Gateway API | Supported opt-in | `cilium_gateway_api_enabled = true` installs standard Gateway API CRDs and enables Cilium Gateway API. Requires Cilium with kube-proxy replacement. |
| Tailscale node transport | Static/plan validated; live E2E pending | `node_transport_mode = "tailscale"` has static validation and plan-matrix coverage; recommended for evaluation, not yet certified for production topologies. |
| Embedded registry mirror | Supported opt-in | Enables k3s/RKE2's embedded Spegel mirror for trusted larger clusters. |
| Cilium multinetwork public overlay | Experimental preview | Gated by `enable_experimental_cilium_public_overlay`; not production-supported until live datapath validation passes. |
| Flannel multinetwork scale over Hetzner Networks | Static/plan validated through Tailscale transport; live E2E pending | Flannel is the first supported CNI for `node_transport_mode = "tailscale"`; Cilium multinetwork remains the separate experimental public-overlay preview until live datapath coverage promotes it. |
| Cloudflare Zero Trust Access/Tunnel | Documented external access pattern | Use user-managed Cloudflare Access/Tunnel for operator, SSH, Rancher, or ingress access. kube-hetzner does not manage Cloudflare resources or support Cloudflare Mesh/WARP as node transport in v3. |
| User-owned Tailscale/ZeroTier/WireGuard/WARP access | Supported external pattern | Use generic hooks when you only want Terraform/operator access and do not want kube-hetzner to manage node transport. |
| Robot/vSwitch coupling | Advanced/special-case | Prefer blue/green migration and review route exposure carefully. |

## Which Topology Should I Use?
| Need | Recommended v3 topology |
| --- | --- |
| Small dev cluster | Single control plane, one agent pool, no ingress unless needed. |
| Normal HA | 3 control planes, 2+ agents, one primary Hetzner Network, public API LB restricted to your source CIDRs or an explicit secure endpoint. |
| Private-only | `nat_router` plus private control-plane LB on the primary Network. |
| Secure operator/API access | `node_transport_mode = "tailscale"` with public API/SSH firewall sources closed. |
| Cloudflare-protected operator/app access | Keep Tailscale or Hetzner private transport underneath; put user-managed Cloudflare Access/Tunnel in front of kube API, SSH, Rancher, or ingress endpoints. |
| More than 100 Cloud nodes | Tailscale node transport plus `network_scope = "external"` shards, one Hetzner Network per 100-node budget. |
| Very large reference | Autoscaler-first Tailscale multinetwork; see the 200-node and 10k-node examples. |
| Cilium Gateway API | Cilium, `enable_kube_proxy = false`, `cilium_gateway_api_enabled = true`. |
| Heavy image-pull pressure | `embedded_registry_mirror.enabled = true` on trusted clusters. |

Full guide: [`docs/v3-topology-recommendations.md`](v3-topology-recommendations.md).

Public node join endpoints require a real public API host: either
`control_plane_endpoint`, a public control-plane load balancer, or public
IPv4/IPv6 on the control-plane nodes. IPv6-only public joins are valid; private
control planes without one of those hosts are rejected during validation.

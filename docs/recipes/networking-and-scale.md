# Networking and Scale Recipes

Advanced network construction, secure transport, large-cluster layout, and private access patterns.

[Recipe index](../recipes.md) | [Documentation index](../index.md)

<details>
<summary><strong>Pre-constructed private network (proxies)</strong></summary>

```tf
resource "hcloud_network" "k3s_proxied" {
  name     = "k3s-proxied"
  ip_range = "10.0.0.0/8"
}

resource "hcloud_network_subnet" "k3s_proxy" {
  network_id   = hcloud_network.k3s_proxied.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.128.0.0/9"
}

resource "hcloud_server" "your_proxy_server" { ... }

resource "hcloud_server_network" "your_proxy_server" {
  depends_on = [hcloud_server.your_proxy_server]
  server_id  = hcloud_server.your_proxy_server.id
  network_id = hcloud_network.k3s_proxied.id
  ip         = "10.128.0.1"
}

module "kube-hetzner" {
  existing_network = { id = hcloud_network.k3s_proxied.id }  # Note: object required!
  network_ipv4_cidr = "10.0.0.0/9"
  additional_kubernetes_install_environment = {
    "http_proxy" : "http://10.128.0.1:3128",
    "HTTP_PROXY" : "http://10.128.0.1:3128",
    "HTTPS_PROXY" : "http://10.128.0.1:3128",
    "CONTAINERD_HTTP_PROXY" : "http://10.128.0.1:3128",
    "CONTAINERD_HTTPS_PROXY" : "http://10.128.0.1:3128",
    "NO_PROXY" : "127.0.0.0/8,10.0.0.0/8,",
  }
}
```
</details>

<details>
<summary><strong>Tailscale node transport</strong></summary>

Tailscale node transport is useful even before a cluster outgrows one Hetzner
Network. In a normal single-network cluster it gives Terraform, kubeconfig, and
operator SSH a private Tailnet path, so you can close public Kubernetes API and
SSH firewall rules without introducing a separate bastion workflow. Kubernetes
still keeps Hetzner private node IPs, so Hetzner CCM, CSI, and Load Balancers
continue to see provider-owned addresses instead of Tailnet `100.64.0.0/10`
addresses.

For clusters that need more than one Hetzner Cloud Network, the same transport
becomes the production v3 scale-out path. Hetzner Networks still cap attached
resources per Network and do not route separate Networks together. Tailscale
fills that gap by advertising each node's own Hetzner private `/32` route into
the Tailnet and accepting those routes on every node.

Tailscale mode does not require exposing Kubernetes itself to the web. The
recommended large-cluster shape keeps public Kubernetes API and SSH firewall
rules closed, disables managed public ingress unless you explicitly need it,
and uses the Tailnet for operator/API/node transport. Nodes may still have
public IPv4/IPv6 enabled so they can bootstrap Tailscale and form direct
WireGuard paths; the public firewall opens Tailscale UDP/41641, not Kubernetes
API, SSH, or HTTP/S. A truly no-public-IP multinetwork topology needs private
egress and externally managed Tailscale bootstrap for every external Network;
the module NAT router covers only the primary kube-hetzner Network.

Minimal secure single-network shape:

```tf
node_transport_mode = "tailscale"

tailscale_auth_key = var.tailscale_auth_key

tailscale_node_transport = {
  # cloud_init brings Tailscale up before Terraform starts using SSH.
  bootstrap_mode  = "cloud_init"
  magicdns_domain = "example-tailnet.ts.net"
  auth = {
    mode = "auth_key"
  }
  routing = {
    # Single-network clusters already have Hetzner private reachability between
    # nodes, so route approval is optional. Leave this true for multinetwork.
    advertise_node_private_routes = false
  }
}

# Tailscale mode deliberately rejects public world-open API/SSH defaults.
firewall_kube_api_source = null
firewall_ssh_source      = null

# Every active Tailscale agent/autoscaler nodepool sets network_scope explicitly.
# Use "primary" when network_id is omitted/null.
# agent_nodepools = [{
#   name = "agent", server_type = "cx23", location = "nbg1",
#   labels = [], taints = [], count = 2, network_scope = "primary"
# }]
```

Multinetwork scale-out adds `network_scope = "external"` nodepools with
external `network_id` values and requires approved node-private routes. Set
`network_scope` explicitly in Tailscale mode so
Terraform can validate primary-vs-external Network intent during `plan`, even
when a `network_id` comes from an `hcloud_network` resource created in the same
root.

```tf
node_transport_mode = "tailscale"

# Use a reusable shared key, or role-specific keys when autoscaler nodes should
# use a reusable ephemeral key while static nodes use durable tagged keys.
tailscale_auth_key = var.tailscale_auth_key
# tailscale_control_plane_auth_key = var.tailscale_control_plane_auth_key
# tailscale_agent_auth_key         = var.tailscale_agent_auth_key
# tailscale_autoscaler_auth_key    = var.tailscale_autoscaler_auth_key

tailscale_node_transport = {
  bootstrap_mode  = "cloud_init" # required when autoscaler_nodepools are used
  magicdns_domain = "example-tailnet.ts.net"
  auth = {
    mode = "auth_key"
    # Tagged nodes are recommended for production ACLs and route auto-approval,
    # but tags must be owned/permitted in your Tailnet policy before use.
    # advertise_tags_control_plane = ["tag:kube-hetzner-control-plane"]
    # advertise_tags_agent         = ["tag:kube-hetzner-agent"]
    # advertise_tags_autoscaler    = ["tag:kube-hetzner-autoscaler"]
  }
  routing = {
    advertise_node_private_routes = true
  }
}

agent_nodepools = [
  {
    name        = "agent-small-a"
    server_type = "cx23"
    location    = "nbg1"
    labels      = []
    taints      = []
    count       = 50
    # network_id omitted/null means the primary kube-hetzner network.
    network_scope = "primary"
  },
  {
    name        = "agent-small-b"
    server_type = "cx23"
    location    = "nbg1"
    labels      = []
    taints      = []
    count       = 50
    network_id    = 11959154 # existing external private network id
    network_scope = "external"
  },
]

autoscaler_nodepools = [
  {
    name        = "autoscaled-a"
    server_type = "cx23"
    location    = "nbg1"
    min_nodes   = 0
    max_nodes   = 50
    network_scope = "primary"
  },
  {
    name        = "autoscaled-b"
    server_type = "cx23"
    location    = "nbg1"
    min_nodes   = 0
    max_nodes   = 50
    network_id    = 11959154
    network_scope = "external"
  },
]
```

Large-scale reference layouts live in
[`examples/tailscale-node-transport`](../../examples/tailscale-node-transport/):

- [`large-scale-200.tf.example`](../../examples/tailscale-node-transport/large-scale-200.tf.example)
  shows 200 total nodes across two Hetzner Networks while keeping each Network
  at exactly 100 attachments.
- [`massive-10000-nodes.tf.example`](../../examples/tailscale-node-transport/massive-10000-nodes.tf.example)
  shows the reference topology for 10,000 total nodes: 3 control planes, 7
  static system agents, 90 autoscaled primary workers, and 99 external
  100-node autoscaler shards. This is a quota/design reference, not a casual
  default; it requires Hetzner capacity approvals, Tailnet policy/device
  capacity, and production Kubernetes scale planning.

The important constraints are enforced during `terraform plan`:

- `node_transport_mode = "tailscale"` is mutually exclusive with
  `multinetwork_mode = "cilium_public_overlay"`.
- Control planes always stay on the primary kube-hetzner network and no longer
  accept `network_id`.
- Static agents and autoscaler nodepools may use `network_id` to spread across
  existing Hetzner private Networks. In Tailscale mode, every active static
  agent node, agent nodepool, and autoscaler nodepool must set
  `network_scope = "primary"` or `network_scope = "external"`.
- Control planes are not auto-attached to every external agent Network, avoiding
  Hetzner's 3-Networks-per-server limit.
- The module can advertise each node's Hetzner private `/32` route through
  Tailscale, accepts Tailnet routes on nodes, and disables Tailscale
  subnet-route SNAT so Kubernetes/CNI traffic keeps the real Hetzner node
  source IP.
- Single-network clusters may set
  `tailscale_node_transport.routing.advertise_node_private_routes = false` to
  avoid Tailnet route approvals. Any nodepool with `network_scope = "external"`
  requires the default `true`.
- For multinetwork clusters, Tailnet ACLs must auto-approve node-private routes
  for the users, groups, or node tags you use, or the cluster will wait for
  manual route approval. Tags are optional in `auth_key` mode, but they are the
  cleanest production ACL boundary once `tagOwners` and `autoApprovers` are
  configured.
- With `auth.mode = "auth_key"`, use a reusable `tailscale_auth_key` for one
  shared key, or role-specific keys (`tailscale_control_plane_auth_key`,
  `tailscale_agent_auth_key`, `tailscale_autoscaler_auth_key`). A single-use
  key only registers the first node. Prefer a reusable, pre-approved, tagged,
  ephemeral key for autoscaler nodes.
- With `auth.mode = "oauth_client_secret"`, the module passes role-specific
  OAuth auth-key parameters: static nodes default to durable devices and
  autoscaler-created nodes default to ephemeral devices.
- Tailscale mode rejects world-open `firewall_kube_api_source` and
  `firewall_ssh_source`; use `null` for no public API/SSH rule or restrict to
  explicit CIDRs.
- Public module-managed control-plane Load Balancers are rejected in Tailscale
  mode. Private control-plane Load Balancers remain available for single-network
  HA/API patterns; kubeconfig still defaults to the first control plane's
  Tailnet MagicDNS endpoint unless you set an explicit endpoint.
- `autoscaler_nodepools` require `tailscale_node_transport.bootstrap_mode =
  "cloud_init"` because autoscaler-created nodes cannot be configured by
  Terraform remote-exec before joining.
- The module NAT router can be combined with Tailscale only for
  single-primary-network private egress. It does not provide egress for
  external Hetzner Networks, so multinetwork Tailscale nodepools need their own
  public IPv4/IPv6 egress. Do not set `nat_router` for external-network
  Tailscale topologies in this release.
- Managed Hetzner private Load Balancers work for single-primary-network
  Tailscale clusters. They still cannot span external nodepool Networks; when
  using `network_id` scale-out, use public LB targets, Klipper, no/custom
  ingress, or an external load balancer.

The older `multinetwork_mode = "cilium_public_overlay"` path remains as a
gated lab preview for Cilium-only public transport experiments. Prefer
Tailscale node transport for real private multinetwork clusters.
</details>

<details>
<summary><strong>Placement groups</strong></summary>

Assign nodepools to placement groups:

```tf
agent_nodepools = [
  {
    ...
    placement_group = "special"
  },
]
```

Legacy compatibility:
```tf
placement_group_index = 1
```

Count-based nodepools without an explicit `placement_group` are automatically
sharded into spread groups of 10 servers. Hetzner projects also cap placement
groups at 50 total, so very large static clusters must either disable placement
groups, split across projects/clusters, or use autoscaler nodepools for burst
capacity. kube-hetzner does not currently assign Hetzner Placement Groups to
autoscaler-created nodes. If you set an explicit `placement_group`, split
groups manually:
```tf
agent_nodepools = [
  {
    nodes = {
      "0"  : { placement_group = "pg-1" },
      "30" : { placement_group = "pg-2" },
    }
  },
]
```

Disable globally: `enable_placement_groups = false`
</details>

<details>
<summary><strong>Migrating from count to map-based nodes</strong></summary>

Set `append_index_to_node_name = false` to avoid node replacement:

```tf
agent_nodepools = [
  {
    name        = "agent-large",
    server_type = "cx33",
    location    = "nbg1",
    labels      = [],
    taints      = [],
    nodes = {
      "0" : {
        append_index_to_node_name = false,
        labels = ["my.extra.label=special"],
        placement_group = "agent-large-pg-1",
      },
      "1" : {
        append_index_to_node_name = false,
        server_type = "cx43",
        labels = ["my.extra.label=slightlybiggernode"],
        placement_group = "agent-large-pg-2",
      },
    }
  },
]
```
</details>

<details>
<summary><strong>Delete protection</strong></summary>

Protect resources from accidental deletion via Hetzner Console/API:

```tf
enable_delete_protection = {
  floating_ip   = true
  load_balancer = true
  volume        = true
}
```

> Note: Terraform can still delete resources (provider lifts the lock).
</details>

<details>
<summary><strong>Private-only cluster (WireGuard)</strong></summary>

Requirements:
1. Pre-configured network
2. NAT gateway with public IP ([Hetzner guide](https://community.hetzner.com/tutorials/how-to-set-up-nat-for-cloud-networks))
3. WireGuard VPN access ([Hetzner guide](https://docs.hetzner.com/cloud/apps/list/wireguard/))
4. Route `0.0.0.0/0` through NAT gateway

Configuration:
```tf
existing_network = { id = 1234567 }
network_ipv4_cidr = "10.0.0.0/9"

# In all nodepools:
enable_public_ipv4 = false
enable_public_ipv6 = false

# For autoscaler:
autoscaler_enable_public_ipv4 = false
autoscaler_enable_public_ipv6 = false

# Optional private LB:
control_plane_load_balancer_enable_public_network = false
```
</details>

<details>
<summary><strong>Private-only cluster (NAT Router)</strong></summary>

Fully private setup with:
- **Egress:** Single NAT router IP
- **SSH:** Through bastion (NAT router)
- **Control plane:** Through LB or NAT router port forwarding
- **Ingress:** Through agents LB only

```tf
enable_control_plane_load_balancer = true

nat_router = {
  server_type = "cax21"
  location    = "nbg1"
}

# Optional: use the router's private IP for SSH bastion traffic when the
# operator already reaches the private network through Tailscale/WireGuard/etc.
# use_private_nat_router_bastion = true
```

> **August 11, 2025:** Hetzner removed legacy Router DHCP option. This module now automatically persists routes via the virtual gateway.
</details>

<details>
<summary><strong>External user-owned overlays (Tailscale/ZeroTier/WireGuard/WARP)</strong></summary>

Use `node_transport_mode = "tailscale"` when Tailscale should be the official
Kubernetes node transport for a single-network or multinetwork cluster. This
external-overlay pattern is different: it is for operator access, custom
control-plane endpoints, or post-bootstrap Tailscale Kubernetes Operator
features that you manage outside kube-hetzner.

There is still no broad `enable_tailscale` switch. kube-hetzner manages only
the narrow node-transport contract above. It does not manage tailnet ACLs,
route approvals, Tailscale Services, workload ingress/egress policy, or the
Tailscale Kubernetes Operator lifecycle. Use your overlay setup in an outer
module or out-of-band bootstrap, then pass resulting endpoints back into
kube-hetzner.

Cloudflare Zero Trust is documented separately because it is usually an
Access/Tunnel edge rather than a node-to-node transport. Do not use Cloudflare
Mesh/WARP as an officially supported kube-hetzner node transport in v3; use
Tailscale for that contract.

The supported kube-hetzner primitives are:

- `preinstall_exec` / `postinstall_exec` for user-owned bootstrap hooks.
- `node_connection_overrides` for Terraform SSH/provisioners over Tailnet IPs.
- `control_plane_endpoint` for a stable external kube API endpoint.
- `use_private_nat_router_bastion` when a Tailscale/WireGuard/WARP path already reaches the private network.
- `firewall_ssh_source` / `firewall_kube_api_source` tightening after overlay access is proven.

```tf
# Bootstrap overlay client on each node (example commands only).
# Avoid long-lived auth keys here; command strings and cloud-init user-data can
# be visible in Terraform state/provider state or instance logs. Prefer an
# external bootstrap or short-lived, one-use preauth keys that are immediately
# rotated/revoked.
preinstall_exec = [
  "curl -fsSL https://tailscale.com/install.sh | sh",
  # "tailscale up --auth-key=${var.tailscale_auth_key} --ssh --hostname=$(hostname)",
]

# After overlay IPs are known, route Terraform SSH through them
# Keys must match final node names (with cluster prefix if enabled)
node_connection_overrides = {
  "k3s-control-plane" = "100.64.0.10"
  "k3s-agent-0"       = "100.64.0.11"
}

# Optional: use an external control-plane endpoint exposed through overlay
control_plane_endpoint = "https://cp.tailnet.example:6443"
```

Typical workflow:
1. Apply once to bootstrap nodes and install/join overlay agents.
2. Resolve overlay addresses and set `node_connection_overrides`.
3. Apply again and optionally tighten `firewall_ssh_source` / `firewall_kube_api_source`.
4. After Kubernetes is healthy, deploy the Tailscale Kubernetes Operator with
   Helm, ArgoCD, or `user_kustomizations` if you want Tailscale Services,
   workload ingress/egress, subnet routers, or kube API proxying.

For cluster node transport, prefer
[`examples/tailscale-node-transport/README.md`](../../examples/tailscale-node-transport/README.md).
For user-owned Tailscale operator access, see
[`examples/external-overlay-tailscale/README.md`](../../examples/external-overlay-tailscale/README.md).
For Cloudflare Access/Tunnel operator and app access, see
[`examples/external-overlay-cloudflare-access/README.md`](../../examples/external-overlay-cloudflare-access/README.md).
</details>

<details>
<summary><strong>Cloudflare Zero Trust Access/Tunnel (external)</strong></summary>

Cloudflare Zero Trust is useful in v3 as an operator and application access
layer. Keep the cluster transport underneath simple:

- Use `node_transport_mode = "tailscale"` for supported secure node transport,
  especially single-network hardening and multinetwork scale-out.
- Use Cloudflare Access/Tunnel for the Kubernetes API, SSH, Rancher, Grafana,
  or ingress hostnames that you choose to publish through Cloudflare.
- Manage Cloudflare accounts, policies, tunnels, DNS records, WARP enrollment,
  and service tokens outside kube-hetzner.

This module deliberately does not add a Cloudflare provider, Cloudflare token
variables, Cloudflare Mesh bootstrap, or `node_transport_mode = "cloudflare"`.
Cloudflare Mesh is still beta in Cloudflare's own docs, and using it as
Kubernetes node transport would create a large support surface that v3 does not
need.

For kubeconfig access through Cloudflare Access, prefer a local helper path such
as `cloudflared access tcp` or a WARP/private-route design owned outside this
module. Do not point `control_plane_endpoint` at an Access-protected hostname
unless every joining control-plane and agent node can reach and authenticate to
that endpoint; `control_plane_endpoint` is also used for node joins.

For SSH, use Cloudflare's own Access SSH patterns, or expose reachable overlay
addresses through `node_connection_overrides` only after you have proven that
Terraform can connect through them.

Full example:
[`examples/external-overlay-cloudflare-access/README.md`](../../examples/external-overlay-cloudflare-access/README.md).
</details>

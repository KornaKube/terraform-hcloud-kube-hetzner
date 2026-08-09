# Add-ons and Ingress Recipes

Patterns for post-install applications, Cilium, registry distribution, ingress TLS, and Helm-managed add-ons.

[Recipe index](../recipes.md) | [Documentation index](../index.md)

<details>
<summary><strong>Custom post-install actions (ArgoCD, etc.)</strong></summary>

For CRD-dependent applications:

```tf
user_kustomizations = {
  "1" = {
    source_folder = "extra-manifests"
    kustomize_parameters = {
      target_namespace = "argocd"
    }
    pre_commands = ""
    post_commands = <<-EOT
      kubectl -n argocd wait --for condition=established --timeout=120s crd/appprojects.argoproj.io
      kubectl -n argocd wait --for condition=established --timeout=120s crd/applications.argoproj.io
      kubectl apply -f /var/user_kustomize/1/argocd-projects.yaml
      kubectl apply -f /var/user_kustomize/1/argocd-application-argocd.yaml
    EOT
  }
}
```
</details>

<details>
<summary><strong>Useful Cilium commands</strong></summary>

```sh
# Status
kubectl -n kube-system exec --stdin --tty cilium-xxxx -- cilium status --verbose

# Monitor traffic
kubectl -n kube-system exec --stdin --tty cilium-xxxx -- cilium monitor

# List services
kubectl -n kube-system exec --stdin --tty cilium-xxxx -- cilium service list
```

[Full Cilium cheatsheet](https://docs.cilium.io/en/latest/cheatsheet)
</details>

<details>
<summary><strong>Cilium Egress Gateway with Floating IPs</strong></summary>

Control outgoing traffic with static IPs:

```tf
{
  name        = "egress",
  server_type = "cx23",
  location    = "nbg1",
  labels      = ["node.kubernetes.io/role=egress"],
  taints      = ["node.kubernetes.io/role=egress:NoSchedule"],
  floating_ip = true,
  count       = 1
}
```

Configure Cilium:
```tf
locals {
  cluster_ipv4_cidr = "10.42.0.0/16"
}

cluster_ipv4_cidr = local.cluster_ipv4_cidr
enable_kube_proxy = false

cilium_values = <<-EOT
ipam:
  mode: kubernetes
k8s:
  requireIPv4PodCIDR: true
kubeProxyReplacement: true
routingMode: native
ipv4NativeRoutingCIDR: "10.0.0.0/8"
endpointRoutes:
  enabled: true
loadBalancer:
  acceleration: native
bpf:
  masquerade: true
egressGateway:
  enabled: true
MTU: 1450
EOT
```

Cilium Egress Gateway requires kube-proxy replacement, so keep `enable_kube_proxy = false` when enabling it.

```tf
# Optional: keep selected egress policies pinned to a Ready egress node automatically
cilium_egress_gateway_ha_enabled = true
```

Example policy:
```yaml
apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata:
  name: egress-sample
  labels:
    kube-hetzner.io/egress-ha: "true"
spec:
  selectors:
    - podSelector:
        matchLabels:
          org: empire
          class: mediabot
          io.kubernetes.pod.namespace: default
  destinationCIDRs:
    - "0.0.0.0/0"
  excludedCIDRs:
    - "10.0.0.0/8"
  egressGateway:
    nodeSelector:
      matchLabels:
        node.kubernetes.io/role: egress
    egressIP: { FLOATING_IP }
```

[Full Egress Gateway docs](https://docs.cilium.io/en/stable/network/egress-gateway/)
</details>

<details>
<summary><strong>Cilium Gateway API</strong></summary>

Cilium can own Gateway API directly:

```tf
cni_plugin                 = "cilium"
enable_kube_proxy         = false
cilium_gateway_api_enabled = true
```

When enabled, kube-hetzner installs the standard Gateway API CRDs for the
selected Cilium line, enables `gatewayAPI.enabled` in Cilium values, and enables
cert-manager Gateway API support. This is separate from Traefik's Kubernetes
Gateway provider. Choose one Gateway API controller per cluster; v3 rejects
enabling Cilium Gateway API and Traefik's Gateway provider at the same time.

Use [`examples/cilium-gateway-api`](../../examples/cilium-gateway-api/) for a working
GatewayClass/Gateway/HTTPRoute/cert-manager HTTP-01 starting point.

</details>

<details>
<summary><strong>Embedded Registry Mirror</strong></summary>

k3s and RKE2 can use their embedded Spegel registry mirror to share images
between trusted cluster nodes:

```tf
embedded_registry_mirror = {
  enabled                  = true
  registries               = ["docker.io", "registry.k8s.io", "ghcr.io", "quay.io"]
  disable_default_endpoint = false
}
```

kube-hetzner sets `embedded-registry: true` on server nodes and merges empty
mirror entries into the effective `registries.yaml`. Existing
`registries_config` entries and endpoints are preserved.

This is opt-in because the mirror assumes equal node trust. Images pulled with
credentials on one node may be shared with other nodes, and tags can be poisoned
by a node that can place images in containerd. Use digest-pinned images for
critical workloads. In Tailscale multinetwork clusters, advertised node-private
routes are required so the mirror can reach peers across Network shards.

</details>

<details>
<summary><strong>HelmChartConfig customization</strong></summary>

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rancher
  namespace: kube-system
spec:
  valuesContent: |-
    # Your values.yaml customizations here
```

Works for add-ons installed through HelmChart resources, including Longhorn,
cert-manager, and Traefik.
</details>

<details>
<summary><strong>TLS with Cert-Manager (recommended)</strong></summary>

Cert-Manager handles HA certificate management (Traefik CE is stateless).

1. [Configure your issuer](https://cert-manager.io/docs/configuration/acme/)
2. Add annotations to Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
    - hosts:
        - "*.example.com"
      secretName: example-com-letsencrypt-tls
  rules:
    - host: "*.example.com"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

[Full Traefik + Cert-Manager guide](https://traefik.io/blog/secure-web-applications-with-traefik-proxy-cert-manager-and-lets-encrypt/)

> **Ingress-Nginx with HTTP challenge:** Add `load_balancer_hostname = "cluster.example.org"` to work around [this known issue](https://github.com/cert-manager/cert-manager/issues/466).

> **F5 NGINX Ingress Controller:** `ingress_controller = "nginx"` installs the Kubernetes ingress-nginx controller. To run the F5 controller, set `ingress_controller = "none"` and install F5's chart separately.
</details>

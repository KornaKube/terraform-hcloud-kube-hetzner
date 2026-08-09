# Recipes

Recipes are grouped by operational domain so you can copy one pattern without searching through the README or an unrelated guide. Start from [`kube.tf.example`](../kube.tf.example), take only the settings you need, and inspect the complete Terraform/OpenTofu plan before applying it.

[Documentation index](index.md) | [Support matrix](support-matrix.md) | [Topology recommendations](v3-topology-recommendations.md)

## Recipe Guides

| Guide | Includes |
| --- | --- |
| [Add-ons and ingress](recipes/addons-and-ingress.md) | User kustomizations, Cilium operations and Gateway API, embedded registry mirror, TLS, and HelmChartConfig. |
| [Images and runtime](recipes/images-and-runtime.md) | Leap Micro/MicroOS snapshot builds, custom snapshots, single-node clusters, and Terraform Cloud. |
| [Storage and recovery](recipes/storage-and-recovery.md) | HCloud CSI and Longhorn encryption, architecture scheduling, and etcd S3 restore. |
| [Networking and scale](recipes/networking-and-scale.md) | Proxies, Tailscale, placement groups, map-based nodes, private clusters, external overlays, and Cloudflare Access/Tunnel. |
| [Security](recipes/security.md) | Targeted SELinux workload policy generation with `udica`. |

## Working Examples

- [`examples/argocd`](../examples/argocd/) configures Kubernetes and Helm providers from `kubeconfig_data` and installs ArgoCD.
- [`examples/tailscale-node-transport`](../examples/tailscale-node-transport/) covers secure single-network transport and private multinetwork scale-out.
- [`examples/cilium-gateway-api`](../examples/cilium-gateway-api/) includes Cilium Gateway API, HTTPRoute, and cert-manager HTTP-01 resources.
- [`examples/cilium-multinetwork`](../examples/cilium-multinetwork/) is the experimental Cilium public-overlay preview.
- [`examples/external-overlay-tailscale`](../examples/external-overlay-tailscale/) shows user-owned operator access with `node_connection_overrides`.
- [`examples/external-overlay-cloudflare-access`](../examples/external-overlay-cloudflare-access/) documents a user-managed Cloudflare Zero Trust boundary.
- [`examples/kustomization_user_deploy`](../examples/kustomization_user_deploy/) demonstrates ordered `user_kustomizations` sets.
- [`examples/tls`](../examples/tls/) contains basic Traefik and cert-manager TLS resources.

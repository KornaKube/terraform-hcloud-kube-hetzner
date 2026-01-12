#cloud-config

write_files:

${cloudinit_write_files_common}

- content: ${base64encode(k3s_config)}
  encoding: base64
  path: /tmp/config.yaml

- content: ${base64encode(install_k3s_agent_script)}
  encoding: base64
  path: /var/pre_install/install-k3s-agent.sh

# Apply DNS config
%{ if has_dns_servers ~}
manage_resolv_conf: true
resolv_conf:
  nameservers:
%{ for dns_server in dns_servers ~}
    - ${dns_server}
%{ endfor ~}
%{ endif ~}

# Add ssh authorized keys
ssh_authorized_keys:
%{ for key in sshAuthorizedKeys ~}
  - ${key}
%{ endfor ~}

# Resize /var, not /, as that's the last partition in MicroOS image.
growpart:
    devices: ["/var"]

# Make sure the hostname is set correctly
hostname: ${hostname}
preserve_hostname: true

runcmd:

${cloudinit_runcmd_common}

# Configure default routes based on public ip availability
%{if private_network_only~}
# Private-only setup: detect the private interface dynamically
- |
  route_dev() {
    awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
  }
  PRIV_IF=$(ip -4 route get '${network_gw_ipv4}' 2>/dev/null | route_dev)
  if [ -z "$PRIV_IF" ]; then
    PRIV_IF=$(ip -4 route show scope link 2>/dev/null | route_dev)
  fi
  if [ -n "$PRIV_IF" ]; then
    ip route replace default via '${network_gw_ipv4}' dev "$PRIV_IF" metric 100
  else
    echo "WARN: could not determine private interface for default route" >&2
  fi
%{else~}
# Standard setup: detect public interface dynamically (ARM uses enp7s0, x86 uses eth0)
- |
  route_dev() {
    awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
  }
  PUB_IF=$(ip -4 route get 172.31.1.1 2>/dev/null | route_dev)
  if [ -z "$PUB_IF" ]; then
    # Fallback to eth0 if detection fails
    PUB_IF="eth0"
  fi
  ip route replace default via 172.31.1.1 dev "$PUB_IF" metric 100
  ip -6 route replace default via fe80::1 dev "$PUB_IF" metric 100
%{endif~}

# Start the install-k3s-agent service
- ['/bin/bash', '/var/pre_install/install-k3s-agent.sh']

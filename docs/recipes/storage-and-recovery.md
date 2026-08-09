# Storage and Recovery Recipes

Storage encryption, workload architecture placement, and etcd recovery patterns.

[Recipe index](../recipes.md) | [Documentation index](../index.md)

<details>
<summary><strong>Encryption at rest (HCloud CSI)</strong></summary>

Create secret:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: encryption-secret
  namespace: kube-system
stringData:
  encryption-passphrase: foobar
```

Create storage class:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hcloud-volumes-encrypted
provisioner: csi.hetzner.cloud
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  csi.storage.k8s.io/node-publish-secret-name: encryption-secret
  csi.storage.k8s.io/node-publish-secret-namespace: kube-system
```
</details>

<details>
<summary><strong>Encryption at rest (Longhorn)</strong></summary>

Create secret:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: longhorn-crypto
  namespace: longhorn-system
stringData:
  CRYPTO_KEY_VALUE: "your-encryption-key"
  CRYPTO_KEY_PROVIDER: "secret"
  CRYPTO_KEY_CIPHER: "aes-xts-plain64"
  CRYPTO_KEY_HASH: "sha256"
  CRYPTO_KEY_SIZE: "256"
  CRYPTO_PBKDF: "argon2i"
```

Create storage class:
```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-crypto-global
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  nodeSelector: "node-storage"
  numberOfReplicas: "1"
  staleReplicaTimeout: "2880"
  fromBackup: ""
  fsType: ext4
  encrypted: "true"
  csi.storage.k8s.io/provisioner-secret-name: "longhorn-crypto"
  csi.storage.k8s.io/provisioner-secret-namespace: "longhorn-system"
  csi.storage.k8s.io/node-publish-secret-name: "longhorn-crypto"
  csi.storage.k8s.io/node-publish-secret-namespace: "longhorn-system"
  csi.storage.k8s.io/node-stage-secret-name: "longhorn-crypto"
  csi.storage.k8s.io/node-stage-secret-namespace: "longhorn-system"
```

[Longhorn encryption docs](https://longhorn.io/docs/1.4.0/advanced-resources/security/volume-encryption/)
</details>

<details>
<summary><strong>Namespace-based architecture assignment</strong></summary>

Enable admission controllers:
```tf
control_plane_exec_args = "--kube-apiserver-arg enable-admission-plugins=PodTolerationRestriction,PodNodeSelector"
```

Assign namespace to architecture:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    scheduler.alpha.kubernetes.io/node-selector: kubernetes.io/arch=amd64
  name: this-runs-on-amd64
```

With tolerations:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    scheduler.alpha.kubernetes.io/node-selector: kubernetes.io/arch=arm64
    scheduler.alpha.kubernetes.io/defaultTolerations: '[{ "operator" : "Equal", "effect" : "NoSchedule", "key" : "workload-type", "value" : "machine-learning" }]'
  name: this-runs-on-arm64
```
</details>

<details>
<summary><strong>Backup and restore cluster (etcd S3)</strong></summary>

**Setup backup:**

1. Configure `etcd_s3_backup` in kube.tf
2. Add cluster_token output:

```tf
output "cluster_token" {
  value     = module.kube-hetzner.cluster_token
  sensitive = true
}
```

**Restore:**

1. Add restoration config to kube.tf:

```tf
locals {
  cluster_token = var.cluster_token
  etcd_version = "v3.5.9"
  etcd_snapshot_name = "name-of-the-snapshot"
  etcd_s3_endpoint = "your-s3-endpoint"
  etcd_s3_bucket = "your-s3-bucket"
  etcd_s3_access_key = "your-s3-access-key"
  etcd_s3_secret_key = var.etcd_s3_secret_key
}

variable "cluster_token" {
  sensitive = true
  type      = string
}

variable "etcd_s3_secret_key" {
  sensitive = true
  type      = string
}

module "kube-hetzner" {
  cluster_token = local.cluster_token

  postinstall_exec = compact([
    (
      local.etcd_snapshot_name == "" ? "" :
      <<-EOF
      export CLUSTERINIT=$(cat /etc/rancher/k3s/config.yaml | grep -i '"cluster-init": true')
      if [ -n "$CLUSTERINIT" ]; then
        k3s server \
          --cluster-reset \
          --etcd-s3 \
          --cluster-reset-restore-path=${local.etcd_snapshot_name} \
          --etcd-s3-endpoint=${local.etcd_s3_endpoint} \
          --etcd-s3-bucket=${local.etcd_s3_bucket} \
          --etcd-s3-access-key=${local.etcd_s3_access_key} \
          --etcd-s3-secret-key=${local.etcd_s3_secret_key}
        mv /etc/rancher/k3s/k3s.yaml /etc/rancher/k3s/k3s.backup.yaml

        ETCD_VER=${local.etcd_version}
        case "$(uname -m)" in
            aarch64) ETCD_ARCH="arm64" ;;
            x86_64) ETCD_ARCH="amd64" ;;
        esac;
        DOWNLOAD_URL=https://github.com/etcd-io/etcd/releases/download
        curl -L $DOWNLOAD_URL/$ETCD_VER/etcd-$ETCD_VER-linux-$ETCD_ARCH.tar.gz -o /tmp/etcd-$ETCD_VER-linux-$ETCD_ARCH.tar.gz
        tar xzvf /tmp/etcd-$ETCD_VER-linux-$ETCD_ARCH.tar.gz -C /usr/local/bin --strip-components=1

        nohup etcd --data-dir /var/lib/rancher/k3s/server/db/etcd &
        echo $! > save_pid.txt

        etcdctl del /registry/services/specs/traefik/traefik
        etcdctl del /registry/services/endpoints/traefik/traefik

        OLD_NODES=$(etcdctl get "" --prefix --keys-only | grep /registry/minions/ | cut -c 19-)
        for NODE in $OLD_NODES; do
          for KEY in $(etcdctl get "" --prefix --keys-only | grep $NODE); do
            etcdctl del $KEY
          done
        done

        kill -9 `cat save_pid.txt`
        rm save_pid.txt
      fi
      EOF
    )
  ])
}
```

2. Set environment variables:
```sh
export TF_VAR_cluster_token="..."
export TF_VAR_etcd_s3_secret_key="..."
```

3. Run `terraform apply`
</details>

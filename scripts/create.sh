#!/usr/bin/env bash

set -euo pipefail

folder_name="${folder_name:-}"
folder_path="${folder_path:-}"
create_snapshots="${create_snapshots:-}"
HCLOUD_TOKEN="${HCLOUD_TOKEN:-}"
KH_SOURCE_COMMIT="${KH_SOURCE_COMMIT:-}"
KH_SOURCE_ARCHIVE_SHA256="${KH_SOURCE_ARCHIVE_SHA256:-}"
KH_PACKER_BUNDLE_MANIFEST_SHA256="${KH_PACKER_BUNDLE_MANIFEST_SHA256:-}"
KH_SOURCE_REF="${KH_SOURCE_REF:-master}"

# Downloaded use defaults to master. Exceptional strict remote use requires
# KH_SOURCE_COMMIT, KH_SOURCE_ARCHIVE_SHA256, and
# KH_PACKER_BUNDLE_MANIFEST_SHA256 together. KH_SOURCE_DIRECTORY is reserved
# for an explicitly selected local checkout and cannot be combined with pins.

# Check if terraform, packer and hcloud CLIs are present
command -v ssh >/dev/null 2>&1 || {
    echo "openssh is not installed. Install it with 'brew install openssh'."
    exit 1
}

if command -v tofu >/dev/null 2>&1 ; then
    terraform_command=tofu
elif command -v terraform >/dev/null 2>&1 ; then
    terraform_command=terraform
else
    echo "terraform or tofu is not installed. Install it with 'brew tap hashicorp/tap && brew install hashicorp/tap/terraform' or 'brew install opentofu'."
    exit 1
fi

command -v packer >/dev/null 2>&1 || {
    echo "Packer 1.16.0 is required. Install it from https://releases.hashicorp.com/packer/1.16.0/."
    exit 1
}
command -v hcloud >/dev/null 2>&1 || {
    echo "hcloud (Hetzner CLI) is not installed. Install it with 'brew install hcloud'."
    exit 1
}
for required_tool in curl tar; do
    command -v "$required_tool" >/dev/null 2>&1 || {
        echo "${required_tool} is required to download the kube-hetzner source bundle." >&2
        exit 1
    }
done

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print tolower($1)}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print tolower($1)}'
    else
        echo "sha256sum or shasum is required to verify the Packer security bundle." >&2
        exit 1
    fi
}

require_sha256() {
    local label="$1"
    local value="$2"
    if [[ ! "$value" =~ ^[0-9a-f]{64}$ ]]; then
        echo "${label} must be exactly 64 lowercase hexadecimal characters." >&2
        exit 1
    fi
}

require_source_ref() {
    local value="$1"
    if [[ ! "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] ||
       [[ "$value" == *..* ]] ||
       [[ "$value" == *//* ]] ||
       [[ "$value" == */ ]]; then
        echo "KH_SOURCE_REF must be a simple branch, tag, or commit name." >&2
        exit 1
    fi
}

# Ask for the folder name
if [ -z "${folder_name}" ] ; then
    read -r -p "Enter the name of the folder you want to create (leave empty to use the current directory instead, useful for upgrades): " folder_name
fi

# Ask for the folder path only if folder_name is provided
if [ -n "$folder_name" ] && [ -z "${folder_path}" ]; then
    read -r -p "Enter the path to create the folder in (default: current path): " folder_path
fi

# Set default path if not provided
if [ -z "$folder_path" ]; then
    folder_path="."
fi

# Create the folder if folder_name is provided
if [ -n "$folder_name" ]; then
    mkdir -p "${folder_path}/${folder_name}"
    folder_path="${folder_path}/${folder_name}"
fi

source_directory="${KH_SOURCE_DIRECTORY:-}"
bundle_directory=""

if [ -n "$source_directory" ] &&
   { [ -n "$KH_SOURCE_COMMIT" ] ||
     [ -n "$KH_SOURCE_ARCHIVE_SHA256" ] ||
     [ -n "$KH_PACKER_BUNDLE_MANIFEST_SHA256" ]; }; then
    echo "KH_SOURCE_DIRECTORY cannot be combined with remote source pins." >&2
    exit 1
fi

cleanup_source_bundle() {
    if [ -n "$bundle_directory" ]; then
        rm -rf "$bundle_directory"
    fi
}
trap cleanup_source_bundle EXIT

ensure_source_directory() {
    local source_ref

    if [ -n "$source_directory" ]; then
        return
    fi

    if [ -n "$KH_SOURCE_COMMIT" ] ||
       [ -n "$KH_SOURCE_ARCHIVE_SHA256" ] ||
       [ -n "$KH_PACKER_BUNDLE_MANIFEST_SHA256" ]; then
        if [[ ! "$KH_SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
            echo "Pinned remote mode requires a full 40-character KH_SOURCE_COMMIT." >&2
            exit 1
        fi
        require_sha256 "KH_SOURCE_ARCHIVE_SHA256" "$KH_SOURCE_ARCHIVE_SHA256"
        require_sha256 "KH_PACKER_BUNDLE_MANIFEST_SHA256" "$KH_PACKER_BUNDLE_MANIFEST_SHA256"
        source_ref="$KH_SOURCE_COMMIT"
    else
        require_source_ref "$KH_SOURCE_REF"
        source_ref="$KH_SOURCE_REF"
    fi

    bundle_directory="$(mktemp -d)"
    archive_file="$bundle_directory/kube-hetzner.tar.gz"
    source_directory="$bundle_directory/source"
    mkdir -p "$source_directory"
    curl -fsS --proto '=https' --tlsv1.2 --max-redirs 0 \
        --retry 3 --retry-all-errors --connect-timeout 20 --max-time 300 \
        --max-filesize 536870912 \
        "https://codeload.github.com/mysticaltech/terraform-hcloud-kube-hetzner/tar.gz/${source_ref}" \
        -o "$archive_file"
    if [ -n "$KH_SOURCE_ARCHIVE_SHA256" ] &&
       [ "$(sha256_file "$archive_file")" != "$KH_SOURCE_ARCHIVE_SHA256" ]; then
        echo "Commit-addressed source archive digest mismatch." >&2
        exit 1
    fi
    tar -xzf "$archive_file" -C "$source_directory" --strip-components=1
}

publish_file_if_missing() (
    local source_file="$1"
    local destination="$2"
    local display_name="$3"
    local temporary_file=""

    trap 'if [ -n "$temporary_file" ]; then rm -f "$temporary_file"; fi' EXIT
    trap 'exit 1' HUP INT TERM

    temporary_file="$(umask 077 && mktemp "${destination}.tmp.XXXXXX")"
    cp -p "$source_file" "$temporary_file"

    # A same-filesystem hard link publishes atomically and fails if another
    # invocation or user creates the destination first.
    if ln "$temporary_file" "$destination" 2>/dev/null; then
        return
    fi

    if [ -e "$destination" ] || [ -L "$destination" ]; then
        echo "${display_name} already exists. Skipping download."
        return
    fi

    echo "Unable to publish ${display_name} without overwriting the destination." >&2
    return 1
)

install_if_missing() {
    local destination="$1"
    local relative_source="$2"
    local display_name="${destination#"${folder_path}/"}"
    local source_file

    if [ -e "$destination" ] || [ -L "$destination" ]; then
        echo "${display_name} already exists. Skipping download."
        return
    fi

    ensure_source_directory
    source_file="$source_directory/$relative_source"
    if [ ! -f "$source_file" ]; then
        echo "Source bundle is missing ${relative_source}." >&2
        exit 1
    fi

    mkdir -p "$(dirname "$destination")"
    publish_file_if_missing "$source_file" "$destination" "$display_name"
}

# Keep the user-owned Terraform configuration outside the all-or-nothing
# Packer trust bundle.
install_if_missing "${folder_path}/kube.tf" "kube.tf.example"

ensure_source_directory
packer_source_directory="$source_directory/packer-template"
packer_manifest="$packer_source_directory/security-bundle.sha256"
packer_bundle_installer="$packer_source_directory/scripts/install-packer-security-bundle.sh"

if [ -z "$KH_PACKER_BUNDLE_MANIFEST_SHA256" ]; then
    KH_PACKER_BUNDLE_MANIFEST_SHA256="$(sha256_file "$packer_manifest")"
fi
require_sha256 "KH_PACKER_BUNDLE_MANIFEST_SHA256" "$KH_PACKER_BUNDLE_MANIFEST_SHA256"
actual_manifest_sha256="$(sha256_file "$packer_manifest")"
if [ "$actual_manifest_sha256" != "$KH_PACKER_BUNDLE_MANIFEST_SHA256" ]; then
    echo "Packer security bundle manifest digest mismatch." >&2
    exit 1
fi

# Verify the helper before executing it; the helper then verifies and publishes
# the complete bundle through one atomic directory link.
expected_installer_sha256="$(awk '
    $2 == "scripts/install-packer-security-bundle.sh" && NF == 2 {
        count++
        digest = $1
    }
    END {
        if (count == 1) print digest
        else exit 1
    }
' "$packer_manifest")" || {
    echo "Packer security bundle manifest must contain exactly one installer entry." >&2
    exit 1
}
require_sha256 "Packer bundle installer digest" "$expected_installer_sha256"
if [ "$(sha256_file "$packer_bundle_installer")" != "$expected_installer_sha256" ]; then
    echo "Packer security bundle installer digest mismatch." >&2
    exit 1
fi

bash "$packer_bundle_installer" \
    "$packer_source_directory" \
    "${folder_path}/packer" \
    "$KH_PACKER_BUNDLE_MANIFEST_SHA256"
packer_directory="${folder_path}/packer"

# Ask which snapshots they want to create
if [ -z "${create_snapshots}" ] ; then
    echo " "
    echo "The snapshots are required and deployed using packer."
    echo "Leap Micro is the recommended default OS for new clusters. MicroOS is kept for legacy/upgrade scenarios."
    echo " "
    read -r -p "Which snapshots do you want to create now? (leapmicro/microos/both/none) [leapmicro]: " create_snapshots
fi

if [[ -z "$create_snapshots" ]]; then
    create_snapshots="leapmicro"
fi

if [[ "$create_snapshots" =~ ^([Yy]es|[Yy])$ ]]; then
    create_snapshots="leapmicro"
fi

if [[ "$create_snapshots" =~ ^([Nn]o|[Nn])$ ]]; then
    create_snapshots="none"
fi

if [[ "$create_snapshots" != "none" ]]; then
    if [[ -z "$HCLOUD_TOKEN" ]]; then
        read -r -s -p "Enter your HCLOUD_TOKEN: " hcloud_token
        echo
        export HCLOUD_TOKEN="$hcloud_token"
    fi
    "$packer_directory/scripts/install-verified-packer-plugin-hcloud.sh"
fi

case "$create_snapshots" in
    leapmicro)
        echo "Running packer build matrix for hcloud-leapmicro-snapshots.pkr.hcl (k3s + rke2, x86 + ARM)"
        cd "$packer_directory" && packer init hcloud-leapmicro-snapshots.pkr.hcl
        for distro in k3s rke2; do
          echo "Building Leap Micro snapshots for distro: ${distro}"
          packer build -var "selinux_package_to_install=${distro}" hcloud-leapmicro-snapshots.pkr.hcl
        done
        ;;
    microos)
        echo "Running packer build matrix for hcloud-microos-snapshots.pkr.hcl (k3s + rke2, x86 + ARM)"
        cd "$packer_directory" && packer init hcloud-microos-snapshots.pkr.hcl
        for distro in k3s rke2; do
          echo "Building MicroOS snapshots for distro: ${distro}"
          packer build -var "selinux_package_to_install=${distro}" hcloud-microos-snapshots.pkr.hcl
        done
        ;;
    both)
        echo "Running packer build matrices for both Leap Micro and MicroOS (k3s + rke2, x86 + ARM)"
        cd "$packer_directory" && packer init hcloud-leapmicro-snapshots.pkr.hcl
        for distro in k3s rke2; do
          echo "Building Leap Micro snapshots for distro: ${distro}"
          packer build -var "selinux_package_to_install=${distro}" hcloud-leapmicro-snapshots.pkr.hcl
        done
        packer init hcloud-microos-snapshots.pkr.hcl
        for distro in k3s rke2; do
          echo "Building MicroOS snapshots for distro: ${distro}"
          packer build -var "selinux_package_to_install=${distro}" hcloud-microos-snapshots.pkr.hcl
        done
        ;;
    none)
        echo " "
        echo "You can create the snapshots later by running:"
        echo "  cd packer"
        echo "  ./scripts/install-verified-packer-plugin-hcloud.sh"
        echo "  for distro in k3s rke2; do packer build -var \"selinux_package_to_install=\${distro}\" hcloud-leapmicro-snapshots.pkr.hcl; done"
        echo "  for distro in k3s rke2; do packer build -var \"selinux_package_to_install=\${distro}\" hcloud-microos-snapshots.pkr.hcl; done"
        ;;
    *)
        echo "Invalid choice for create_snapshots: '$create_snapshots' (expected leapmicro/microos/both/none)"
        exit 1
        ;;
esac

# Output commands
echo " "
echo "Remember, don't skip the hcloud cli, to activate it run 'hcloud context create <project-name>'. It is ideal to quickly debug and allows targeted cleanup when needed!"
echo " "
echo "Before running '${terraform_command} apply', go through the kube.tf file and fill it with your desired values."

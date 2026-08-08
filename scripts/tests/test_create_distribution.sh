#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_bin="$tmp/bin"
target_parent="$tmp/output"
target="$target_parent/fixture"
mkdir -p "$fake_bin" "$target_parent"

system_cp="$(command -v cp)"

grep -Fq -- '--connect-timeout 20 --max-time 300' "$repo_root/scripts/create.sh" \
  || { echo 'FAIL: source archive download is missing bounded network timeouts' >&2; exit 1; }
grep -Fq -- '--max-filesize 536870912' "$repo_root/scripts/create.sh" \
  || { echo 'FAIL: source archive download is missing a size bound' >&2; exit 1; }
grep -Fq -- "https://codeload.github.com/mysticaltech/terraform-hcloud-kube-hetzner/tar.gz/\${KH_SOURCE_COMMIT}" "$repo_root/scripts/create.sh" \
  || { echo 'FAIL: source archive download does not use the canonical immutable Codeload path' >&2; exit 1; }

for command_name in hcloud packer ssh tofu; do
  printf '#!/bin/sh\nexit 0\n' > "$fake_bin/$command_name"
  chmod 700 "$fake_bin/$command_name"
done

run_create() {
  local fixture_name="${1:-fixture}"
  local source_directory="${2:-$repo_root}"
  local extra_bin="${3:-}"
  local run_path="$fake_bin:$PATH"

  if [[ -n "$extra_bin" ]]; then
    run_path="$extra_bin:$run_path"
  fi

  env \
    PATH="$run_path" \
    KH_SOURCE_DIRECTORY="$source_directory" \
    folder_name="$fixture_name" \
    folder_path="$target_parent" \
    create_snapshots=none \
    bash "$repo_root/scripts/create.sh" >/dev/null
}

assert_no_temporary_files() {
  local directory="$1"
  local temporary_file

  temporary_file="$(find "$directory" -name '*.tmp.*' -print -quit)"
  [[ -z "$temporary_file" ]] \
    || { echo "FAIL: create.sh left temporary file $temporary_file" >&2; exit 1; }
}

make_source_fixture() {
  local destination="$1"
  local kube_contents="$2"

  mkdir -p "$destination"
  printf '%s\n' "$kube_contents" > "$destination/kube.tf.example"
  "$system_cp" -R "$repo_root/packer-template" "$destination/packer-template"
}

run_create
[[ -L "$target/packer" ]] \
  || { echo 'FAIL: create.sh did not atomically publish the Packer bundle' >&2; exit 1; }

while IFS='|' read -r expected actual; do
  [[ -f "$target/packer/$actual" ]] || { echo "FAIL: create.sh omitted packer/$actual" >&2; exit 1; }
  cmp "$repo_root/$expected" "$target/packer/$actual" \
    || { echo "FAIL: create.sh changed $actual during download" >&2; exit 1; }
done <<'FILES'
packer-template/hcloud-microos-snapshots.pkr.hcl|hcloud-microos-snapshots.pkr.hcl
packer-template/hcloud-leapmicro-snapshots.pkr.hcl|hcloud-leapmicro-snapshots.pkr.hcl
packer-template/keys/opensuse-project-signing-key.asc|keys/opensuse-project-signing-key.asc
packer-template/keys/rancher-ci-signing-key.asc|keys/rancher-ci-signing-key.asc
packer-template/scripts/install-packer-security-bundle.sh|scripts/install-packer-security-bundle.sh
packer-template/scripts/install-verified-packer-plugin-hcloud.sh|scripts/install-verified-packer-plugin-hcloud.sh
packer-template/scripts/verify-leapmicro-image.sh|scripts/verify-leapmicro-image.sh
packer-template/scripts/verify-microos-image.sh|scripts/verify-microos-image.sh
packer-template/scripts/verify-rancher-rpm.sh|scripts/verify-rancher-rpm.sh
packer-template/scripts/install-verified-rancher-rpm.sh|scripts/install-verified-rancher-rpm.sh
FILES
cmp "$repo_root/kube.tf.example" "$target/kube.tf" \
  || { echo 'FAIL: create.sh changed kube.tf during download' >&2; exit 1; }
[[ -x "$target/packer/scripts/verify-leapmicro-image.sh" ]] \
  || { echo 'FAIL: create.sh did not preserve executable source modes' >&2; exit 1; }
[[ -x "$target/packer/scripts/verify-microos-image.sh" ]] \
  || { echo 'FAIL: create.sh did not preserve the MicroOS verifier executable mode' >&2; exit 1; }

printf 'preserve-existing-user-file\n' > "$target/kube.tf"
run_create
grep -Fxq 'preserve-existing-user-file' "$target/kube.tf" \
  || { echo 'FAIL: create.sh overwrote an existing user file' >&2; exit 1; }

preplanted_target="$target_parent/preplanted"
preplanted_victim="$tmp/preplanted-victim"
preplanted_path_file="$tmp/preplanted-path"
mkdir -p "$preplanted_target"
printf 'must-not-be-overwritten\n' > "$preplanted_victim"
# Expansion belongs to the child Bash process.
# shellcheck disable=SC2016
env \
  PATH="$fake_bin:$PATH" \
  KH_SOURCE_DIRECTORY="$repo_root" \
  CREATE_TEST_PREPLANTED_TARGET="$preplanted_target" \
  CREATE_TEST_PREPLANTED_VICTIM="$preplanted_victim" \
  CREATE_TEST_PREPLANTED_PATH_FILE="$preplanted_path_file" \
  folder_name=preplanted \
  folder_path="$target_parent" \
  create_snapshots=none \
  bash -c '
    temporary_link="$CREATE_TEST_PREPLANTED_TARGET/kube.tf.tmp.$$"
    ln -s "$CREATE_TEST_PREPLANTED_VICTIM" "$temporary_link"
    printf "%s\n" "$temporary_link" > "$CREATE_TEST_PREPLANTED_PATH_FILE"
    exec bash "$1"
  ' _ "$repo_root/scripts/create.sh" >/dev/null
preplanted_path="$(cat "$preplanted_path_file")"
grep -Fxq 'must-not-be-overwritten' "$preplanted_victim" \
  || { echo 'FAIL: create.sh followed a pre-planted predictable temp symlink' >&2; exit 1; }
cmp "$repo_root/kube.tf.example" "$preplanted_target/kube.tf" \
  || { echo 'FAIL: create.sh did not publish kube.tf beside a pre-planted temp symlink' >&2; exit 1; }
[[ -L "$preplanted_path" ]] \
  || { echo 'FAIL: create.sh reused or removed an attacker-owned temp symlink' >&2; exit 1; }

race_bin="$tmp/race-bin"
race_target="$target_parent/destination-race"
mkdir -p "$race_bin" "$race_target"
cat > "$race_bin/cp" <<'RACE_CP'
#!/usr/bin/env bash
set -euo pipefail

"$CREATE_TEST_SYSTEM_CP" "$@"
temporary_file="${!#}"
if [[ "$temporary_file" == "${CREATE_TEST_RACE_DESTINATION}.tmp."* ]]; then
  printf 'racing-user-file\n' > "$CREATE_TEST_RACE_DESTINATION"
fi
RACE_CP
chmod 700 "$race_bin/cp"
export CREATE_TEST_SYSTEM_CP="$system_cp"
export CREATE_TEST_RACE_DESTINATION="$race_target/kube.tf"
run_create destination-race "$repo_root" "$race_bin"
unset CREATE_TEST_RACE_DESTINATION
grep -Fxq 'racing-user-file' "$race_target/kube.tf" \
  || { echo 'FAIL: create.sh overwrote a destination created during publication' >&2; exit 1; }
assert_no_temporary_files "$race_target"

concurrent_bin="$tmp/concurrent-bin"
concurrent_barrier="$tmp/concurrent-barrier"
concurrent_target="$target_parent/concurrent"
source_a="$tmp/source-a"
source_b="$tmp/source-b"
mkdir -p "$concurrent_bin" "$concurrent_barrier" "$concurrent_target"
make_source_fixture "$source_a" 'concurrent-winner-a'
make_source_fixture "$source_b" 'concurrent-winner-b'
cat > "$concurrent_bin/cp" <<'CONCURRENT_CP'
#!/usr/bin/env bash
set -euo pipefail

"$CREATE_TEST_SYSTEM_CP" "$@"
temporary_file="${!#}"
if [[ "$temporary_file" == "${CREATE_TEST_CONCURRENT_DESTINATION}.tmp."* ]]; then
  : > "$CREATE_TEST_CONCURRENT_BARRIER/${CREATE_TEST_RUN_ID}.ready"
  while [[ "$(find "$CREATE_TEST_CONCURRENT_BARRIER" -name '*.ready' | wc -l | tr -d ' ')" -lt 2 ]]; do
    sleep 0.01
  done
  if [[ "$CREATE_TEST_RUN_ID" == B ]]; then
    while [[ ! -e "$CREATE_TEST_CONCURRENT_DESTINATION" ]]; do
      sleep 0.01
    done
  fi
fi
CONCURRENT_CP
chmod 700 "$concurrent_bin/cp"
export CREATE_TEST_CONCURRENT_BARRIER="$concurrent_barrier"
export CREATE_TEST_CONCURRENT_DESTINATION="$concurrent_target/kube.tf"
env \
  PATH="$concurrent_bin:$fake_bin:$PATH" \
  KH_SOURCE_DIRECTORY="$source_a" \
  CREATE_TEST_RUN_ID=A \
  folder_name=concurrent \
  folder_path="$target_parent" \
  create_snapshots=none \
  bash "$repo_root/scripts/create.sh" >/dev/null &
create_a_pid=$!
env \
  PATH="$concurrent_bin:$fake_bin:$PATH" \
  KH_SOURCE_DIRECTORY="$source_b" \
  CREATE_TEST_RUN_ID=B \
  folder_name=concurrent \
  folder_path="$target_parent" \
  create_snapshots=none \
  bash "$repo_root/scripts/create.sh" >/dev/null &
create_b_pid=$!
wait "$create_a_pid"
wait "$create_b_pid"
grep -Fxq 'concurrent-winner-a' "$concurrent_target/kube.tf" \
  || { echo 'FAIL: a concurrent create.sh invocation replaced the first published file' >&2; exit 1; }
assert_no_temporary_files "$concurrent_target"

cleanup_bin="$tmp/cleanup-bin"
cleanup_target="$target_parent/cleanup"
mkdir -p "$cleanup_bin" "$cleanup_target"
cat > "$cleanup_bin/cp" <<'CLEANUP_CP'
#!/usr/bin/env bash
set -euo pipefail

temporary_file="${!#}"
: > "$temporary_file"
exit 73
CLEANUP_CP
chmod 700 "$cleanup_bin/cp"
if run_create cleanup "$repo_root" "$cleanup_bin" > "$tmp/copy-failure.log" 2>&1; then
  echo 'FAIL: create.sh hid a source copy failure' >&2
  exit 1
fi
assert_no_temporary_files "$cleanup_target"

printf '#!/bin/sh\nexit 9\n' > "$fake_bin/packer"
chmod 700 "$fake_bin/packer"
if env \
  PATH="$fake_bin:$PATH" \
  KH_SOURCE_DIRECTORY="$repo_root" \
  folder_name=failing-fixture \
  folder_path="$target_parent" \
  create_snapshots=leapmicro \
  HCLOUD_TOKEN=fixture-token \
  bash "$repo_root/scripts/create.sh" > "$tmp/packer-failure.log" 2>&1; then
  echo 'FAIL: create.sh hid a Packer initialization failure' >&2
  exit 1
fi

echo 'PASS: create.sh atomically distributes one source snapshot, preserves existing and racing files, resists predictable temp symlinks, supports concurrent runs, cleans temporary files, and propagates build failures.'

#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readme="$repo_root/README.md"
site_index="$repo_root/site-docs/index.md"
docs_index="$repo_root/docs/index.md"
troubleshooting="$repo_root/docs/troubleshooting.md"
tmp="$(mktemp -d)"
trap 'find "$tmp" -depth -delete' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

command_after_label() {
  local file="$1"
  local label="$2"

  awk -v label="$label" '
    $0 == label { found = 1; next }
    fenced && /^[[:space:]]*```/ { exit }
    found && /^[[:space:]]*```/ { fenced = 1; next }
    fenced { sub(/^   /, ""); print }
  ' "$file"
}

python3 "$repo_root/scripts/sync_docs_site.py" --check \
  || fail "checked-in site documentation does not match its sources"

if grep -En 'BEGIN_KH_VERIFIED_BOOTSTRAP|__KH_SOURCE_|__KH_PACKER_BUNDLE_' "$site_index"; then
  fail "generated site still exposes release bootstrap internals"
fi
grep -Fq 'master/scripts/create.sh' "$site_index" \
  || fail "generated quick start omits the createkh launcher"
grep -Fq 'Bash/Zsh:' "$site_index" \
  || fail "generated quick start omits the Bash/Zsh createkh command"
grep -Fq 'Fish:' "$site_index" \
  || fail "generated quick start omits the Fish createkh command"
grep -Fq '[generated configuration reference](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/blob/master/docs/terraform.md)' "$site_index" \
  || fail "generated quick start contains a broken documentation link"
quick_start="$(sed -n '/^## Quick Start$/,/^## /p' "$site_index")"
test "$(grep -Ec '^[0-9]+\. ' <<< "$quick_start")" -eq 4 \
  || fail "generated quick start must remain a four-step path"
for step in 1 2 3 4; do
  test "$(grep -Ec "^${step}\\. " <<< "$quick_start")" -eq 1 \
    || fail "generated quick start must contain step $step exactly once"
done
if grep -Eq '<details>|What the script does|Use a specific release' <<< "$quick_start"; then
  fail "generated quick start contains optional or internal setup detail"
fi

test "$(wc -l < "$readme" | tr -d ' ')" -le 350 \
  || fail "README must remain a concise project overview and documentation index"
readme_quick_start="$(sed -n '/^## Quick Start$/,/^## /p' "$readme")"
test "$(grep -Ec '^[0-9]+\. ' <<< "$readme_quick_start")" -eq 4 \
  || fail "README quick start must remain a four-step path"
for step in 1 2 3 4; do
  test "$(grep -Ec "^${step}\\. " <<< "$readme_quick_start")" -eq 1 \
    || fail "README quick start must contain step $step exactly once"
done
screenshot_line="$(grep -nF '.images/kubectl-pod-all-17022022.png' "$readme" | head -1 | cut -d: -f1 || true)"
highlights_line="$(grep -n '^## Highlights$' "$readme" | head -1 | cut -d: -f1 || true)"
test -n "$screenshot_line" && test "$screenshot_line" -lt "$highlights_line" \
  || fail "README must show the running-cluster image in its opening block"
if grep -Eq '^## .*Debugging|K3s certificate expiry' "$readme"; then
  fail "README contains troubleshooting procedures that belong in docs/troubleshooting.md"
fi
grep -Fq 'K3s certificate expiry' "$troubleshooting" \
  || fail "troubleshooting guide omits K3s certificate recovery"
for doc in upgrades.md support-matrix.md operations.md recipes.md troubleshooting.md; do
  grep -Fq "($doc)" "$docs_index" \
    || fail "documentation index omits $doc"
done

create_bash="$(command_after_label "$readme" '   Bash/Zsh:')"
create_fish="$(command_after_label "$readme" '   Fish:')"
cleanup_bash="$(command_after_label "$readme" 'Forceful cleanup fallback:')"
cleanup_fish="$(command_after_label "$readme" '<summary><strong>Fish shell version</strong></summary>')"
kubeconfig_recovery="$(command_after_label "$troubleshooting" 'it before atomically replacing your local copy:')"
takedown="$(sed -n '/^## Remove a Cluster$/,/^## /p' "$readme")"
takedown_bash="$(awk '
  /^```sh$/ { fenced = 1; next }
  fenced && /^```$/ { fenced = 0; print ""; next }
  fenced { print }
' <<< "$takedown")"

[[ "$create_bash" == *'env -u KH_SOURCE_DIRECTORY'* ]] \
  || fail "Bash/Zsh createkh launcher does not clear ambient local source selection"
[[ "$create_fish" == *'env -u KH_SOURCE_DIRECTORY'* ]] \
  || fail "Fish createkh launcher does not clear ambient local source selection"
grep -Fq 'master/scripts/cleanup.sh' <<< "$takedown" \
  || fail "README omits the cleanupkh download"
grep -Fq 'cleanupkh()' <<< "$takedown" \
  || fail "README omits the reusable cleanupkh function"

bash -n -c "$create_bash"
bash -n -c "$takedown_bash"
bash -n -c "$kubeconfig_recovery"

has_zsh=0
has_fish=0
command -v zsh >/dev/null 2>&1 && has_zsh=1
command -v fish >/dev/null 2>&1 && has_fish=1

if [[ "${KH_REQUIRE_OPTIONAL_SHELLS:-0}" == 1 ]]; then
  [[ "$has_zsh" -eq 1 ]] || fail "zsh is required to verify the documented launchers"
  [[ "$has_fish" -eq 1 ]] || fail "fish is required to verify the documented launchers"
fi
[[ "$has_zsh" -eq 1 ]] || printf 'SKIP: zsh unavailable; zsh launcher checks were not run.\n' >&2
[[ "$has_fish" -eq 1 ]] || printf 'SKIP: fish unavailable; fish launcher checks were not run.\n' >&2

if [[ "$has_zsh" -eq 1 ]]; then
  zsh -n -c "$create_bash"
  zsh -n -c "$takedown_bash"
fi
if [[ "$has_fish" -eq 1 ]]; then
  fish -n -c "$create_fish"
  fish -n -c "$cleanup_fish"
fi

fake_bin="$tmp/bin"
launcher_fixture="$tmp/launcher-fixture.sh"
launcher_log="$tmp/launcher.log"
mkdir -p "$fake_bin"
cat > "$fake_bin/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
set -euo pipefail

output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
[[ -n "$output" ]]
"$README_LAUNCHER_SYSTEM_CP" "$README_LAUNCHER_FIXTURE" "$output"
FAKE_CURL
cat > "$launcher_fixture" <<'LAUNCHER_FIXTURE'
#!/usr/bin/env bash
set -euo pipefail

[[ -z "${KH_SOURCE_DIRECTORY:-}" ]]
printf 'executed\n' >> "$README_LAUNCHER_LOG"
LAUNCHER_FIXTURE
cat > "$fake_bin/ssh" <<'FAKE_SSH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${README_SSH_FAIL:-0}" == 1 ]]; then
  exit 42
fi
printf 'apiVersion: v1\nkind: Config\n'
FAKE_SSH
cat > "$fake_bin/kubectl" <<'FAKE_KUBECTL'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${README_KUBECTL_FAIL:-0}" == 1 ]]; then
  exit 43
fi
FAKE_KUBECTL
chmod 700 "$fake_bin/curl" "$fake_bin/ssh" "$fake_bin/kubectl" "$launcher_fixture"

launcher_env=(
  PATH="$fake_bin:$PATH"
  README_LAUNCHER_FIXTURE="$launcher_fixture"
  README_LAUNCHER_LOG="$launcher_log"
  README_LAUNCHER_SYSTEM_CP="$(command -v cp)"
)
env "${launcher_env[@]}" KH_SOURCE_DIRECTORY=/untrusted/local/tree bash -c "$create_bash"
env "${launcher_env[@]}" bash -c "$cleanup_bash"
expected_launcher_runs=2
if [[ "$has_zsh" -eq 1 ]]; then
  env "${launcher_env[@]}" KH_SOURCE_DIRECTORY=/untrusted/local/tree zsh -c "$create_bash"
  env "${launcher_env[@]}" zsh -c "$cleanup_bash"
  expected_launcher_runs=$((expected_launcher_runs + 2))
fi
if [[ "$has_fish" -eq 1 ]]; then
  env "${launcher_env[@]}" KH_SOURCE_DIRECTORY=/untrusted/local/tree fish -c "$create_fish"
  env "${launcher_env[@]}" fish -c "$cleanup_fish"
  expected_launcher_runs=$((expected_launcher_runs + 2))
fi
test "$(wc -l < "$launcher_log" | tr -d ' ')" -eq "$expected_launcher_runs" \
  || fail "documented createkh and cleanupkh launchers did not all execute"

recovery_dir="$tmp/recovery"
mkdir -p "$recovery_dir"
printf 'existing-kubeconfig\n' > "$recovery_dir/clustername_kubeconfig.yaml"
if (cd "$recovery_dir" && env PATH="$fake_bin:$PATH" README_SSH_FAIL=1 bash -c "$kubeconfig_recovery"); then
  fail "K3s kubeconfig recovery continued after a failed SSH fetch"
fi
grep -Fxq 'existing-kubeconfig' "$recovery_dir/clustername_kubeconfig.yaml" \
  || fail "failed SSH fetch replaced the existing K3s kubeconfig"
if (cd "$recovery_dir" && env PATH="$fake_bin:$PATH" README_KUBECTL_FAIL=1 bash -c "$kubeconfig_recovery"); then
  fail "K3s kubeconfig recovery continued after failed validation"
fi
grep -Fxq 'existing-kubeconfig' "$recovery_dir/clustername_kubeconfig.yaml" \
  || fail "failed validation replaced the existing K3s kubeconfig"
(cd "$recovery_dir" && env PATH="$fake_bin:$PATH" bash -c "$kubeconfig_recovery")
grep -Fxq 'apiVersion: v1' "$recovery_dir/clustername_kubeconfig.yaml" \
  || fail "successful K3s kubeconfig recovery did not replace the destination"
test "$(perl -e 'printf "%o\n", (stat($ARGV[0]))[2] & 07777' "$recovery_dir/clustername_kubeconfig.yaml")" = 600 \
  || fail "recovered K3s kubeconfig is not mode 0600"
test -z "$(find "$recovery_dir" -name '.k3s-kubeconfig.tmp.*' -print -quit)" \
  || fail "K3s kubeconfig recovery left a temporary file"

printf 'PASS: generated docs stay simple, shell launchers execute, and K3s kubeconfig recovery is atomic.\n'

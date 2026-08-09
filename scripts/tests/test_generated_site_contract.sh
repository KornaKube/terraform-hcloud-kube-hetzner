#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readme="$repo_root/README.md"
site_index="$repo_root/site-docs/index.md"
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

if rg -n 'BEGIN_KH_VERIFIED_BOOTSTRAP|__KH_SOURCE_|__KH_PACKER_BUNDLE_' "$site_index"; then
  fail "generated site still exposes release bootstrap internals"
fi
grep -Fq 'master/scripts/create.sh' "$site_index" \
  || fail "generated quick start omits the createkh launcher"
grep -Fq 'Bash/Zsh:' "$site_index" \
  || fail "generated quick start omits the Bash/Zsh createkh command"
grep -Fq 'Fish:' "$site_index" \
  || fail "generated quick start omits the Fish createkh command"
quick_start="$(sed -n '/^## Quick Start$/,/^## /p' "$site_index")"
test "$(grep -Ec '^[1-4]\. ' <<< "$quick_start")" -eq 4 \
  || fail "generated quick start must remain a four-step path"
if grep -Eq '<details>|What the script does|Use a specific release' <<< "$quick_start"; then
  fail "generated quick start contains optional or internal setup detail"
fi

create_bash="$(command_after_label "$readme" '   Bash/Zsh:')"
create_fish="$(command_after_label "$readme" '   Fish:')"
cleanup_bash="$(command_after_label "$readme" 'Forceful cleanup fallback:')"
cleanup_fish="$(command_after_label "$readme" '<summary><strong>Fish shell version</strong></summary>')"
kubeconfig_recovery="$(command_after_label "$readme" 'it before atomically replacing your local copy:')"
takedown="$(sed -n '/^## 💣 Takedown$/,/^## /p' "$readme")"
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
zsh -n -c "$create_bash"
zsh -n -c "$takedown_bash"
fish -n -c "$create_fish"
fish -n -c "$cleanup_fish"
bash -n -c "$kubeconfig_recovery"

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
env "${launcher_env[@]}" KH_SOURCE_DIRECTORY=/untrusted/local/tree zsh -c "$create_bash"
env "${launcher_env[@]}" KH_SOURCE_DIRECTORY=/untrusted/local/tree fish -c "$create_fish"
env "${launcher_env[@]}" bash -c "$cleanup_bash"
env "${launcher_env[@]}" zsh -c "$cleanup_bash"
env "${launcher_env[@]}" fish -c "$cleanup_fish"
test "$(wc -l < "$launcher_log" | tr -d ' ')" -eq 6 \
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

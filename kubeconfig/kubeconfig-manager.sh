#!/bin/bash

# kubeconfig-manager.sh
# Usage:
#   kcfg add <name>                     # Merge ~/.kube/kubeconfig-<name>.yaml into ~/.kube/config
#   kcfg scp <user@host:/path> <name>   # Copy remote config and merge it, patching 127.0.0.1 → host
#   kcfg remove <name>                  # Remove context, cluster, and user by name
#   kcfg list                           # List all available contexts
#   kcfg export <name>                  # Export single context to ~/.kube/kubeconfig-<name>.yaml

set -euo pipefail

CONFIG_DIR="$HOME/.kube"
MERGED_CONFIG="$CONFIG_DIR/config"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_CONFIG="$CONFIG_DIR/config.backup.$TIMESTAMP"

# ANSI color helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()    { echo -e "${CYAN}$*${NC}"; }
success(){ echo -e "${GREEN}$*${NC}"; }
warn()   { echo -e "${YELLOW}$*${NC}"; }
error()  { echo -e "${RED}$*${NC}" >&2; }

# Ensure yq is installed
if ! command -v yq &>/dev/null; then
  error "❌ 'yq' is required but not installed. Install: https://github.com/mikefarah/yq"
  exit 1
fi

function usage() {
  echo "Usage:"
  echo "  kcfg add <name>"
  echo "  kcfg scp <user@host:/path/to/kubeconfig> <name>"
  echo "  kcfg remove <name>"
  echo "  kcfg list"
  echo "  kcfg export <name>"
  exit 1
}

function patch_server_and_names() {
  local file="$1"
  local server="$2"
  local name="$3"

  log "🔧 Patching 127.0.0.1 to $server in $file"
  sed -i "s|127.0.0.1|$server|g" "$file"

  log "🔧 Renaming cluster, context, and current-context to $name"

  [[ ! -r "$file" ]] && error "❌ Cannot read file: $file" && ls -lZ "$file" && exit 1

  local tmp
  tmp="$(mktemp)"
  if ! cat "$file" | yq ".clusters[].name = \"$name\" |
                         .contexts[].context.cluster = \"$name\" |
                         .contexts[].name = \"$name\" |
                         .current-context = \"$name\"" > "$tmp"; then
    error "❌ Failed to patch with yq"
    cat "$file"
    exit 1
  fi

  mv "$tmp" "$file"
}

function add_config() {
  local name="$1"
  local file="$CONFIG_DIR/kubeconfig-$name.yaml"

  [[ ! -f "$file" ]] && error "❌ File not found: $file" && exit 1
  [[ ! -w "$file" ]] && error "❌ No write permission for: $file" && exit 1

  log "🛟 Backing up current config to $BACKUP_CONFIG"
  cp "$MERGED_CONFIG" "$BACKUP_CONFIG" 2>/dev/null || touch "$MERGED_CONFIG"

  # Keep only the 5 most recent backups
  find "$CONFIG_DIR" -maxdepth 1 -name "config.backup.*" -type f | sort -r | tail -n +6 | xargs -r rm --

  if kubectl config --kubeconfig="$MERGED_CONFIG" get-contexts "$name" &>/dev/null; then
    warn "⚠️ Context '$name' already exists in config. Skipping merge."
    return
  fi

  success "✅ Merging $file into $MERGED_CONFIG"
  KUBECONFIG="$MERGED_CONFIG:$file" kubectl config view --flatten > "/tmp/kubeconfig-merged.yaml"
  mv "/tmp/kubeconfig-merged.yaml" "$MERGED_CONFIG"
}

function scp_and_patch() {
  local source="$1"
  local name="$2"
  local file="$CONFIG_DIR/kubeconfig-$name.yaml"

  log "📥 Copying from $source to $file"
  scp "$source" "$file"

  chmod 600 "$file"
  setfattr -x security.selinux "$file" 2>/dev/null || true

  for i in {1..10}; do
    [[ -s "$file" && -w "$file" ]] && break
    sleep 0.1
  done

  local host
  host="$(echo "$source" | cut -d@ -f2 | cut -d: -f1)"

  patch_server_and_names "$file" "$host" "$name" || {
    error "❌ Could not patch config. Debug info:"
    ls -lZ "$file"
    file "$file"
    cat "$file"
    exit 1
  }

  add_config "$name"
}

function remove_entry() {
  local name="$1"
  log "🧹 Removing context, cluster, and user: $name"
  kubectl config --kubeconfig="$MERGED_CONFIG" delete-context "$name" || true
  kubectl config --kubeconfig="$MERGED_CONFIG" delete-cluster "$name" || true
  kubectl config --kubeconfig="$MERGED_CONFIG" delete-user "$name" || true
}

function list_contexts() {
  log "📋 Available contexts:"
  kubectl config --kubeconfig="$MERGED_CONFIG" get-contexts -o name
}

function export_config() {
  local name="$1"
  local output="$CONFIG_DIR/kubeconfig-$name.yaml"

  log "📤 Exporting context $name to $output"
  KUBECONFIG="$MERGED_CONFIG" kubectl config view --minify --context="$name" --flatten > "$output"
}

# Entrypoint
[[ $# -lt 1 ]] && usage

case "$1" in
  add)
    [[ $# -ne 2 ]] && usage
    add_config "$2"
    ;;
  scp)
    [[ $# -ne 3 ]] && usage
    scp_and_patch "$2" "$3"
    ;;
  remove)
    [[ $# -ne 2 ]] && usage
    remove_entry "$2"
    ;;
  list)
    list_contexts
    ;;
  export)
    [[ $# -ne 2 ]] && usage
    export_config "$2"
    ;;
  *)
    usage
    ;;
esac

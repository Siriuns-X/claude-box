#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo."
  exit 1
fi

# ===== config =====
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

up() {
  # create Docker network
  if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    docker network create \
      -o com.docker.network.bridge.name="$DOCKER_BRIDGE" \
      --subnet "$DOCKER_SUBNET" "$NETWORK_NAME" \
      --gateway "$DOCKER_GATEWAY"
  fi

  echo "Enabled:"
  echo "  network = $NETWORK_NAME"
  echo "  subnet  = $DOCKER_SUBNET"
}

down() {
  if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    docker network rm "$NETWORK_NAME"
  fi

  echo "Disabled."
}

status() {
  echo "=== Docker network ==="
  docker network inspect "$NETWORK_NAME" 2>/dev/null || true
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  status) status ;;
  *)
    echo "Usage: $0 {up|down|status}"
    exit 1
    ;;
esac

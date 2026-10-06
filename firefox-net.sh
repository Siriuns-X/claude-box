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
  # create namespace
  [[ -e /run/netns/$NAMESPACE ]] || ip netns add "$NAMESPACE"

  # create veth pair
  if ! ip link show "$HOST_IF" >/dev/null 2>&1; then
    ip link add "$HOST_IF" type veth peer name "$NAMESPACE_IF" netns "$NAMESPACE"
  fi
  ip addr replace "$HOST_IP/$PREFIX" dev "$HOST_IF"
  ip link set "$HOST_IF" up

  # configure namespace
  ip -n "$NAMESPACE" link set lo up
  ip -n "$NAMESPACE" addr replace "$NAMESPACE_IP/$PREFIX" dev "$NAMESPACE_IF"
  ip -n "$NAMESPACE" link set "$NAMESPACE_IF" up
  ip -n "$NAMESPACE" route replace default via "$HOST_IP"

  # configure DNS
  mkdir -p /etc/netns/$NAMESPACE
  echo "nameserver $HOST_IP" > /etc/netns/$NAMESPACE/resolv.conf

  echo "Enabled:"
  echo "  namespace = $NAMESPACE"
  echo "  host side = $HOST_IF ($HOST_IP)"
  echo "  namespace side   = $NAMESPACE_IF ($NAMESPACE_IP)"
}

down() {
  ip link del "$HOST_IF" 2>/dev/null || true
  if [[ -e /run/netns/$NAMESPACE ]]; then
    ip netns del "$NAMESPACE"
  fi

  rm -f "/etc/netns/$NAMESPACE/resolv.conf"
  rmdir "/etc/netns/$NAMESPACE" 2>/dev/null || true

  echo "Disabled."
}

status() {
  echo "=== host side ==="
  ip -br addr show "$HOST_IF" 2>/dev/null || echo "$HOST_IF not found"

  echo
  echo "=== namespace $NAMESPACE ==="
  ip netns exec "$NAMESPACE" ip -br addr 2>/dev/null || true
  ip netns exec "$NAMESPACE" ip route 2>/dev/null || true
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

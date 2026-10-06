#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo."
  exit 1
fi

# ===== config =====
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

SOURCE_NETS=(
  "$DOCKER_SUBNET"
  "$FIREFOX_SUBNET"
)

up() {
  # block udp and excluded tcp
  if ! iptables -w -t filter -C DOCKER-USER \
      -i "$DOCKER_BRIDGE" \
      -j REJECT --reject-with icmp-port-unreachable \
  >/dev/null 2>&1; then
    iptables -w -t filter -I DOCKER-USER 1 \
      -i "$DOCKER_BRIDGE" \
      -j REJECT --reject-with icmp-port-unreachable
  fi

  if ! iptables -w -t filter -C FORWARD \
      -i "$HOST_IF" \
      -j REJECT --reject-with icmp-port-unreachable \
  >/dev/null 2>&1; then
      iptables -w -t filter -I FORWARD 1 \
      -i "$HOST_IF" \
      -j REJECT --reject-with icmp-port-unreachable
  fi

  # create NAT chain and reset it
  if ! iptables -w -t nat -S "$CHAIN" \
  >/dev/null 2>&1; then
    iptables -w -t nat -N "$CHAIN"
  fi

  iptables -w -t nat -F "$CHAIN"

  # config exclude
  for net in $EXCLUDE_NETS; do
    iptables -w -t nat -A "$CHAIN" \
      -d "$net" -j RETURN
  done

  # TCP -> Clash redir-port
  iptables -w -t nat -A "$CHAIN" \
    -p tcp -j REDIRECT --to-ports "$REDIRECT_PORT"

  # hook chain into PREROUTING
  for subnet in "${SOURCE_NETS[@]}"; do
    if ! iptables -w -t nat -C PREROUTING \
        -s "$subnet" -j "$CHAIN" \
    >/dev/null 2>&1; then
      iptables -w -t nat -A PREROUTING \
        -s "$subnet" -j "$CHAIN"
    fi
  done

  echo "Enabled:"
  for subnet in "${SOURCE_NETS[@]}"; do
    echo "  subnet  = $subnet"
  done
  echo "  port    = $REDIRECT_PORT"
}

down() {
  # remove udp and excluded tcp rule
  while iptables -w -t filter -C DOCKER-USER \
      -i "$DOCKER_BRIDGE" \
      -j REJECT --reject-with icmp-port-unreachable \
  >/dev/null 2>&1; do
    iptables -w -t filter -D DOCKER-USER \
      -i "$DOCKER_BRIDGE" \
      -j REJECT --reject-with icmp-port-unreachable
  done

  while iptables -w -t filter -C FORWARD \
      -i "$HOST_IF" \
      -j REJECT --reject-with icmp-port-unreachable \
  >/dev/null 2>&1; do
      iptables -w -t filter -D FORWARD \
      -i "$HOST_IF" \
      -j REJECT --reject-with icmp-port-unreachable
  done

  # remove all matching jump rules from PREROUTING
  for subnet in "${SOURCE_NETS[@]}"; do
    while iptables -w -t nat -C PREROUTING \
        -s "$subnet" -j "$CHAIN" \
    >/dev/null 2>&1; do
      iptables -w -t nat -D PREROUTING \
        -s "$subnet" -j "$CHAIN"
    done
  done

  if iptables -w -t nat -L "$CHAIN" \
  >/dev/null 2>&1; then
    iptables -w -t nat -F "$CHAIN"
    iptables -w -t nat -X "$CHAIN"
  fi

  echo "Disabled."
}

status() {
  echo
  echo "=== $CHAIN ==="
  iptables -t nat -L "$CHAIN" -n -v --line-numbers 2>/dev/null || true

  echo
  echo "=== PREROUTING ==="
  iptables -t nat -L PREROUTING -n -v --line-numbers

  echo
  echo "=== FORWARD ==="
  iptables -t filter -L FORWARD -n -v --line-numbers

  echo
  echo "=== DOCKER-USER ==="
  iptables -t filter -L DOCKER-USER -n -v --line-numbers 2>/dev/null || true
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

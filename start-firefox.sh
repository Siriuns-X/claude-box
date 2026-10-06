#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
USER="${SUDO_USER:-$(id -un)}"

source "$SCRIPT_DIR/.env"

sudo ip netns exec $NAMESPACE \
  runuser -u "$USER" -- \
  env WAYLAND_DISPLAY=$WAYLAND_DISPLAY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  firefox -no-remote -profile "$SCRIPT_DIR/profile"

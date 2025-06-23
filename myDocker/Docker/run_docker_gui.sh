#!/usr/bin/env bash
# run_docker_gui_root.sh — GUI-forwarded Docker, container runs as real root
# Usage:
#   run_docker_gui_root.sh <image> [-- <command>]
# Examples:
#   run_docker_gui_root.sh mase
#   run_docker_gui_root.sh mase -- /bin/bash

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <docker-image> [-- <command>]" >&2
  exit 1
fi

IMAGE="$1"; shift

# drop leading “--” if present
if [ $# -gt 0 ] && [ "$1" = "--" ]; then
  shift
fi

# make sure X11 is forwarded
if [ -z "${DISPLAY:-}" ]; then
  echo "ERROR: \$DISPLAY is unset. Connect via 'ssh -X' or 'ssh -Y' first." >&2
  exit 1
fi

# extract only your display’s cookie to a small file
XAUTH_FILE="/tmp/xauth_${USER}"
xauth extract "$XAUTH_FILE" "$DISPLAY"
chmod 644 "$XAUTH_FILE"

# build the docker command as an array
cmd=(
  docker run -it --rm
  --network host
  --userns=host
  -e "DISPLAY=$DISPLAY"
  -e "XAUTHORITY=$XAUTH_FILE"
  -v "/tmp/.X11-unix:/tmp/.X11-unix"
  -v "$XAUTH_FILE:$XAUTH_FILE:ro"
  -v "$HOME/workspace/mase:/workspace"
  "$IMAGE"
)

# append any extra command/args
if [ $# -gt 0 ]; then
  cmd+=( "$@" )
fi

# show and run
echo "Running: ${cmd[@]}"
"${cmd[@]}"

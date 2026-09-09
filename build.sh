#!/usr/bin/env bash
# Local ZMK build via Docker. Usage: ./build.sh [left|right|reset|all] [--pristine]
set -euo pipefail

IMAGE=zmkfirmware/zmk-build-arm:stable
ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-all}"
PRISTINE="${2:-}"

run() { docker run --rm -v "$ROOT:/workspace" -w /workspace \
  -v zmk-build-cache:/root/.cache "$IMAGE" bash -euo pipefail -c "$1"; }

# One-time west workspace init
if [ ! -d "$ROOT/.west" ]; then
  echo "==> initializing west workspace (downloads ~4GB, first run only)"
  run 'west init -l config && west update'
fi

build() { # name, board, shield, extra
  local name="$1" board="$2" shield="$3" extra="${4:-}"
  echo "==> building $name"
  run "west zephyr-export >/dev/null && \
    west build -s zmk/app -d build/$name -b '$board' $extra ${PRISTINE:+--pristine} \
    -- -DZMK_CONFIG=/workspace/config -DSHIELD='$shield'"
  mkdir -p "$ROOT/firmware"
  cp "$ROOT/build/$name/zephyr/zmk.uf2" "$ROOT/firmware/$name.uf2"
}

case "$TARGET" in
  left)  build left  'nice_nano//zmk' 'corne_left nice_view_adapter nice_view' '-S studio-rpc-usb-uart -S zmk-usb-logging' ;;
  right) build right 'nice_nano//zmk' 'corne_right nice_view_adapter nice_view' '-S zmk-usb-logging' ;;
  reset) build reset 'nice_nano//zmk' 'settings_reset' ;;
  all)
    build left  'nice_nano//zmk' 'corne_left nice_view_adapter nice_view' '-S studio-rpc-usb-uart -S zmk-usb-logging'
    build right 'nice_nano//zmk' 'corne_right nice_view_adapter nice_view' '-S zmk-usb-logging'
    build reset 'nice_nano//zmk' 'settings_reset' ;;
  *) echo "unknown target: $TARGET" >&2; exit 1 ;;
esac

echo "==> done: $ROOT/firmware/"
ls -la "$ROOT/firmware/"

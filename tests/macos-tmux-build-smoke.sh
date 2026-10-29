#!/usr/bin/env bash
#
# Slow macOS-only test for the self-contained tmux build.
# Enable with: DEV_ENV_RUN_SLOW_TESTS=1 bash tests/macos-tmux-build-smoke.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ "${DEV_ENV_RUN_SLOW_TESTS:-0}" != "1" ]]; then
  echo "[tmux-build-smoke] 跳过（设置 DEV_ENV_RUN_SLOW_TESTS=1 启用）"
  exit 0
fi
[[ "$(uname -s)" == "Darwin" ]] || {
  echo "[tmux-build-smoke] 非 macOS，跳过"
  exit 0
}

OUT="$(mktemp -d)"
cleanup() { rm -rf "$OUT"; }
trap cleanup EXIT

echo "[tmux-build-smoke] 构建 tmux ..."
bash "$REPO_ROOT/platforms/macos/scripts/build-tmux.sh" --output "$OUT"

"$OUT/tmux" -V
if otool -L "$OUT/tmux" | tail -n +2 | grep -E '/opt/homebrew|/usr/local|@rpath'; then
  echo "[tmux-build-smoke] tmux 仍依赖非系统路径" >&2
  exit 1
fi

case "$(uname -m)" in
  arm64) file "$OUT/tmux" | grep -q arm64 ;;
  x86_64) file "$OUT/tmux" | grep -q x86_64 ;;
esac

echo "[tmux-build-smoke] 通过"

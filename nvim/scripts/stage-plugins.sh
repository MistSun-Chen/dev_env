#!/usr/bin/env bash
#
# 为离线包准备 Neovim 插件和 latex parser。
#
# 运行环境：联网，PATH 中已有 nvim、fzf、git、tree-sitter、cc。
# 产物：
#   <output>/nvim-plugins/      两个插件目录（含 .git）
#   <output>/nvim-parser/latex.so
#   <output>/nvim/nvim-pack-lock.json
#
# 用法：
#   bash nvim/scripts/stage-plugins.sh --output /tmp/bundle
set -euo pipefail

OUT_DIR=""
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$(cd -- "$SCRIPT_DIR/.." && pwd)"
NVIM_BIN="${NVIM_BIN:-nvim}"
TREE_SITTER_BIN="${TREE_SITTER_BIN:-tree-sitter}"
CC="${CC:-cc}"
TMP_ROOT="$(mktemp -d)"

cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

die() { printf '\033[1;31m[stage]\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;32m[stage]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || die "--output 需要一个目录参数"
      OUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "用法: stage-plugins.sh --output DIR"
      exit 0
      ;;
    *) die "未知参数: $1" ;;
  esac
done

[[ -n "$OUT_DIR" ]] || die "缺少 --output"
mkdir -p "$OUT_DIR/nvim" "$OUT_DIR/nvim-plugins" "$OUT_DIR/nvim-parser"

TMP_CONFIG="$TMP_ROOT/config"
TMP_DATA="$TMP_ROOT/data"
mkdir -p "$TMP_CONFIG"
cp -a "$CONFIG_SRC" "$TMP_CONFIG/nvim"

log "安装插件到临时目录 ..."
XDG_CONFIG_HOME="$TMP_CONFIG" XDG_DATA_HOME="$TMP_DATA" \
  NVIM_BIN="$NVIM_BIN" \
  bash "$SCRIPT_DIR/install-plugins.sh"

log "编译 latex parser 到临时目录 ..."
XDG_DATA_HOME="$TMP_DATA" \
  NVIM_BIN="$NVIM_BIN" \
  TREE_SITTER_BIN="$TREE_SITTER_BIN" \
  CC="$CC" \
  bash "$SCRIPT_DIR/build-latex-parser.sh"

log "复制插件与 parser ..."
cp -a "$TMP_DATA/nvim/site/pack/core/opt/." "$OUT_DIR/nvim-plugins/"
cp -a "$TMP_DATA/nvim/site/parser/latex.so" "$OUT_DIR/nvim-parser/latex.so"
cp -a "$TMP_CONFIG/nvim/nvim-pack-lock.json" "$OUT_DIR/nvim/nvim-pack-lock.json"

# 离线包配置目录里也应包含最新的 lockfile；调用方通常已经把 nvim/ 复制过去。
log "完成：$OUT_DIR/nvim-plugins, $OUT_DIR/nvim-parser, $OUT_DIR/nvim/nvim-pack-lock.json"

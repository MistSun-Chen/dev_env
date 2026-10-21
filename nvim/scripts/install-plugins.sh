#!/usr/bin/env bash
#
# 安装/检查 dev_env 的 Neovim 插件。
#
# 用法：
#   bash nvim/scripts/install-plugins.sh
#   bash nvim/scripts/install-plugins.sh --check
#
# 可通过环境变量覆盖：
#   NVIM_BIN=/path/to/nvim
#   XDG_CONFIG_HOME=/path/to/config
#   XDG_DATA_HOME=/path/to/data
#
# 插件清单在 nvim/lua/config/plugins.lua；版本由 nvim-pack-lock.json 固定。
set -euo pipefail

CHECK_ONLY=0
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_DST="$CONFIG_HOME/nvim"
PLUGIN_DIR="$DATA_HOME/nvim/site/pack/core/opt"
NVIM_BIN="${NVIM_BIN:-nvim}"

die() { printf '\033[1;31m[plugins]\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;32m[plugins]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[plugins]\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
用法: install-plugins.sh [选项]

选项:
  --check    只检查插件目录和加载，不触发安装
  -h, --help 显示帮助

环境变量:
  NVIM_BIN         Neovim 可执行文件（默认: nvim）
  XDG_CONFIG_HOME  配置根目录（默认: ~/.config）
  XDG_DATA_HOME    数据根目录（默认: ~/.local/share）
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "未知参数: $1（使用 --help 查看用法）"
      ;;
  esac
done

command -v "$NVIM_BIN" >/dev/null 2>&1 || die "找不到 Neovim：$NVIM_BIN"
if [[ "$CHECK_ONLY" -eq 0 ]]; then
  command -v git >/dev/null 2>&1 || die "找不到 git；vim.pack 需要 git"
  command -v fzf >/dev/null 2>&1 || die "找不到 fzf；请先运行平台安装脚本"
fi

if [[ ! -e "$CONFIG_DST" && ! -L "$CONFIG_DST" ]]; then
  install -d "$CONFIG_HOME"
  ln -sfn "$CONFIG_SRC" "$CONFIG_DST"
  log "已链接配置：$CONFIG_DST -> $CONFIG_SRC"
elif [[ ! -f "$CONFIG_DST/init.lua" ]]; then
  die "配置目录存在但没有 init.lua：$CONFIG_DST"
fi

if [[ "$CHECK_ONLY" -eq 0 ]]; then
  log "触发 vim.pack 安装/加载插件..."
  XDG_CONFIG_HOME="$CONFIG_HOME" XDG_DATA_HOME="$DATA_HOME" \
    "$NVIM_BIN" --headless "+qa"
fi

[[ -f "$CONFIG_DST/nvim-pack-lock.json" ]] || die "缺少 nvim-pack-lock.json：请先联网运行本脚本"
for name in fzf-lua markview.nvim; do
  [[ -d "$PLUGIN_DIR/$name" ]] || die "缺少插件目录：$PLUGIN_DIR/$name"
done
log "插件目录检查通过：$PLUGIN_DIR"

log "验证插件可加载..."
# 用 -u NONE + 显式 rtp，避免验证时再次触发 vim.pack 安装。
"$NVIM_BIN" --headless -u NONE \
  --cmd "set rtp^=$PLUGIN_DIR/fzf-lua" \
  --cmd "set rtp^=$PLUGIN_DIR/markview.nvim" \
  "+lua local ok1,e1=pcall(require,'fzf-lua'); local ok2,e2=pcall(require,'markview'); if not ok1 then error(e1) end; if not ok2 then error(e2) end" +qa

log "插件安装/检查完成。"

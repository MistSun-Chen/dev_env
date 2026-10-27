#!/usr/bin/env bash
#
# macOS 离线安装
#
# 依赖：本脚本与 nvim/、*.tar.gz、SHA256SUMS 在同一目录
#
# 用法：
#   bash install.sh
#   bash install.sh --skip-config
#
set -euo pipefail

SKIP_CONFIG=0
BUNDLE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
. "$BUNDLE_DIR/versions.env"

log()  { printf '\033[1;32m[offline]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[offline]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[offline]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
用法: install.sh [选项]

选项:
  --skip-config   只安装工具，不链接 Neovim 配置
  -h, --help      显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-config)
      SKIP_CONFIG=1
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

[[ "$(uname -s)" == "Darwin" ]] || die "此脚本只支持 macOS。"
[[ "${EUID}" -ne 0 ]] || die "请不要用 root 运行。"

case "$(uname -m)" in
  arm64) ARCH="arm64" ;;
  x86_64) ARCH="x86_64" ;;
  *) die "不支持的 CPU 架构: $(uname -m)" ;;
esac

[[ -f "$BUNDLE_DIR/SHA256SUMS" ]] || die "找不到 SHA256SUMS；请确认整个离线包已拷贝。"
[[ -f "$BUNDLE_DIR/manifest.txt" ]] || die "找不到 manifest.txt；请确认整个离线包已拷贝。"
BUNDLE_ARCH="$(awk -F= '$1 == "arch" { print $2 }' "$BUNDLE_DIR/manifest.txt")"
[[ "$BUNDLE_ARCH" == "$ARCH" ]] || die "离线包架构是 ${BUNDLE_ARCH:-unknown}，当前机器是 ${ARCH}。"

log "校验离线包完整性..."
(
  cd "$BUNDLE_DIR"
  shasum -a 256 -c SHA256SUMS
)

case "$ARCH" in
  arm64)
    NVIM_ASSET="nvim-macos-arm64.tar.gz"
    FZF_ASSET="fzf-${FZF_VERSION}-darwin_arm64.tar.gz"
    RG_ASSET="ripgrep-${RG_VERSION}-aarch64-apple-darwin.tar.gz"
    FD_ASSET="fd-v${FD_VERSION}-aarch64-apple-darwin.tar.gz"
    TREE_SITTER_ASSET="tree-sitter-cli-macos-arm64.zip"
    ;;
  x86_64)
    NVIM_ASSET="nvim-macos-x86_64.tar.gz"
    FZF_ASSET="fzf-${FZF_VERSION}-darwin_amd64.tar.gz"
    RG_ASSET="ripgrep-${RG_VERSION}-x86_64-apple-darwin.tar.gz"
    FD_ASSET="fd-v${FD_VERSION}-x86_64-apple-darwin.tar.gz"
    TREE_SITTER_ASSET="tree-sitter-cli-macos-x64.zip"
    ;;
esac

for f in "$NVIM_ASSET" "$FZF_ASSET" "$RG_ASSET" "$FD_ASSET" "$TREE_SITTER_ASSET"; do
  [[ -f "$BUNDLE_DIR/$f" ]] || die "缺少 $f"
done
[[ -d "$BUNDLE_DIR/nvim" ]] || die "缺少 nvim/ 配置目录"
[[ -d "$BUNDLE_DIR/nvim-plugins" ]] || die "缺少 nvim-plugins/ 目录"
[[ -f "$BUNDLE_DIR/nvim-parser/latex.so" ]] || die "缺少 nvim-parser/latex.so"

LOCAL_BIN="$HOME/.local/bin"
LOCAL_OPT="$HOME/.local/opt"
install -d "$LOCAL_BIN" "$LOCAL_OPT"

log "安装 Neovim $NVIM_VERSION ..."
NVIM_PREFIX="$LOCAL_OPT/nvim-${NVIM_VERSION}"
rm -rf "$NVIM_PREFIX"
install -d "$NVIM_PREFIX"
tar -xzf "$BUNDLE_DIR/$NVIM_ASSET" -C "$NVIM_PREFIX" --strip-components=1
[[ -x "$NVIM_PREFIX/bin/nvim" ]] || die "Neovim 压缩包结构不符合预期。"
ln -sfn "$NVIM_PREFIX/bin/nvim" "$LOCAL_BIN/nvim"

log "安装 fzf $FZF_VERSION ..."
FZF_PREFIX="$LOCAL_OPT/fzf-${FZF_VERSION}"
rm -rf "$FZF_PREFIX"
install -d "$FZF_PREFIX"
tar -xzf "$BUNDLE_DIR/$FZF_ASSET" -C "$FZF_PREFIX"
chmod +x "$FZF_PREFIX/fzf"
ln -sfn "$FZF_PREFIX/fzf" "$LOCAL_BIN/fzf"

log "安装 ripgrep $RG_VERSION ..."
RG_PREFIX="$LOCAL_OPT/ripgrep-${RG_VERSION}"
rm -rf "$RG_PREFIX"
install -d "$RG_PREFIX"
tar -xzf "$BUNDLE_DIR/$RG_ASSET" -C "$RG_PREFIX" --strip-components=1
[[ -x "$RG_PREFIX/rg" ]] || die "ripgrep 压缩包结构不符合预期。"
ln -sfn "$RG_PREFIX/rg" "$LOCAL_BIN/rg"

log "安装 fd $FD_VERSION ..."
FD_PREFIX="$LOCAL_OPT/fd-${FD_VERSION}"
rm -rf "$FD_PREFIX"
install -d "$FD_PREFIX"
tar -xzf "$BUNDLE_DIR/$FD_ASSET" -C "$FD_PREFIX" --strip-components=1
[[ -x "$FD_PREFIX/fd" ]] || die "fd 压缩包结构不符合预期。"
ln -sfn "$FD_PREFIX/fd" "$LOCAL_BIN/fd"

log "安装 tree-sitter $TREE_SITTER_VERSION ..."
TS_PREFIX="$LOCAL_OPT/tree-sitter-${TREE_SITTER_VERSION}"
rm -rf "$TS_PREFIX"
install -d "$TS_PREFIX"
unzip -q -o "$BUNDLE_DIR/$TREE_SITTER_ASSET" -d "$TS_PREFIX"
chmod +x "$TS_PREFIX/tree-sitter"
ln -sfn "$TS_PREFIX/tree-sitter" "$LOCAL_BIN/tree-sitter"

if ! command -v git >/dev/null 2>&1; then
  warn "未找到 git；离线包不包含 git，请安装 Xcode Command Line Tools 或 Homebrew git。"
fi

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  CONFIG_DST="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
  install -d "$(dirname "$CONFIG_DST")"

  if [[ -L "$CONFIG_DST" ]]; then
    current="$(readlink -f "$CONFIG_DST" || true)"
    if [[ "$current" == "$(readlink -f "$BUNDLE_DIR/nvim")" ]]; then
      log "Neovim 配置已经链接到离线包，跳过。"
      CONFIG_DST=""
    fi
  fi

  if [[ -n "${CONFIG_DST:-}" ]]; then
    if [[ -e "$CONFIG_DST" || -L "$CONFIG_DST" ]]; then
      backup="${CONFIG_DST}.bak.$(date +%Y%m%d-%H%M%S)"
      while [[ -e "$backup" || -L "$backup" ]]; do
        backup="${backup}-$$"
      done
      mv "$CONFIG_DST" "$backup"
      log "已备份旧配置: $backup"
    fi
    ln -sfn "$BUNDLE_DIR/nvim" "$CONFIG_DST"
    log "已链接配置: $CONFIG_DST -> $BUNDLE_DIR/nvim"
  fi
else
  log "已跳过 Neovim 配置链接（--skip-config）。"
fi

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
PLUGIN_DST="$DATA_HOME/nvim/lazy"
PARSER_DST="$DATA_HOME/nvim/site/parser"
install -d "$PLUGIN_DST" "$PARSER_DST"

log "安装离线 Neovim 插件 ..."
for name in lazy.nvim which-key.nvim fzf-lua markview.nvim grug-far.nvim neo-tree.nvim nui.nvim plenary.nvim lazydev.nvim nvim-lspconfig catppuccin; do
  [[ -d "$BUNDLE_DIR/nvim-plugins/$name" ]] || die "离线包缺少插件目录: $name"
  rm -rf "$PLUGIN_DST/$name"
  cp -a "$BUNDLE_DIR/nvim-plugins/$name" "$PLUGIN_DST/$name"
done
cp -a "$BUNDLE_DIR/nvim-parser/latex.so" "$PARSER_DST/latex.so"

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  PATH="$LOCAL_BIN:$PATH" \
    NVIM_BIN="$LOCAL_BIN/nvim" \
    XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" \
    XDG_DATA_HOME="$DATA_HOME" \
    bash "$BUNDLE_DIR/nvim/scripts/install-plugins.sh" --check
fi

hash -r

log "版本检查："
"$LOCAL_BIN/nvim" --version | head -n 1
"$LOCAL_BIN/fzf" --version
"$LOCAL_BIN/rg" --version | head -n 1
"$LOCAL_BIN/fd" --version
"$LOCAL_BIN/tree-sitter" --version
if command -v git >/dev/null 2>&1; then
  git --version
fi

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  log "Neovim 配置冒烟测试："
  if ! "$LOCAL_BIN/nvim" --headless \
    "+lua print('number='..tostring(vim.o.number)..' relativenumber='..tostring(vim.o.relativenumber)..' mouse='..vim.o.mouse)" \
    +qa; then
    warn "Neovim 配置加载失败。"
  fi
fi

case ":$PATH:" in
  *":$LOCAL_BIN:"*) ;;
  *)
    warn "当前 PATH 不包含 ${LOCAL_BIN}。"
    warn "请重新登录，或把下面一行加入 ~/.zshrc："
    warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

log "离线安装完成。"
log "启动 Neovim: $LOCAL_BIN/nvim"
log "配置目录: ${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

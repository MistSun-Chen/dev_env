#!/usr/bin/env bash
#
# 离线安装 Ubuntu 24.04 开发环境
#
# 运行环境：离线 Ubuntu 24.04（架构需与下载包一致）
# 依赖：本脚本与 debs/、nvim/、nvim-linux-*.tar.gz、fzf-*.tar.gz、SHA256SUMS 在同一目录
#
# 用法：
#   bash install.sh
#   bash install.sh --skip-config
#   sudo bash install.sh --allow-root     # 仅容器/CI
#
set -euo pipefail

SKIP_CONFIG=0
SKIP_SHELL=0
ALLOW_ROOT=0
SUDO=""

BUNDLE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$BUNDLE_DIR/versions.env" ]]; then
  # shellcheck source=versions.env
  . "$BUNDLE_DIR/versions.env"
else
  . "$(dirname "$BUNDLE_DIR")/versions.env"
fi
if [[ -f "$BUNDLE_DIR/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  . "$BUNDLE_DIR/lib/common.sh"
else
  . "$BUNDLE_DIR/../../../../lib/common.sh"
fi
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_ROOT=""

log()  { printf '\033[1;32m[offline]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[offline]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[offline]\033[0m %s\n' "$*" >&2; exit 1; }
run_sudo() {
  if [[ -n "$SUDO" ]]; then
    "$SUDO" "$@"
  else
    "$@"
  fi
}

usage() {
  cat <<'EOF'
用法: install.sh [选项]

选项:
  --skip-config   只安装工具，不链接 Neovim/tmux/shell 配置
  --skip-shell    只跳过 shell 配置链接
  --allow-root    允许以 root 运行（仅建议在容器/CI 中使用）
  -h, --help      显示帮助

必须把整个离线包目录一起拷到离线机器，不能只拷 install.sh。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-config)
      SKIP_CONFIG=1
      shift
      ;;
    --skip-shell)
      SKIP_SHELL=1
      shift
      ;;
    --allow-root)
      ALLOW_ROOT=1
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

if [[ "${EUID}" -eq 0 ]]; then
  if [[ "$ALLOW_ROOT" -ne 1 ]]; then
    die "请不要直接用 root 运行；容器/CI 中可加 --allow-root。"
  fi
  SUDO=""
else
  command -v sudo >/dev/null 2>&1 || die "需要 sudo 来安装 deb 包。"
  SUDO="sudo"
fi

[[ -r /etc/os-release ]] || die "无法读取 /etc/os-release。"
# shellcheck disable=SC1091
. /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || die "当前系统不是 Ubuntu（ID=${ID:-unknown}）。"
[[ "${VERSION_ID:-}" == "24.04" ]] || die "当前不是 Ubuntu 24.04（VERSION_ID=${VERSION_ID:-unknown}）。"

case "$(uname -m)" in
  x86_64|amd64)
    FZF_ARCH="amd64"
    NVIM_ARCH="x86_64"
    TREE_SITTER_ASSET="tree-sitter-cli-linux-x64.zip"
    STARSHIP_ASSET="starship-x86_64-unknown-linux-musl.tar.gz"
    ;;
  aarch64|arm64)
    FZF_ARCH="arm64"
    NVIM_ARCH="arm64"
    TREE_SITTER_ASSET="tree-sitter-cli-linux-arm64.zip"
    STARSHIP_ASSET="starship-aarch64-unknown-linux-musl.tar.gz"
    ;;
  *)
    die "不支持的 CPU 架构: $(uname -m)"
    ;;
esac

[[ -f "$BUNDLE_DIR/SHA256SUMS" ]] || die "找不到 $BUNDLE_DIR/SHA256SUMS；请确认整个离线包已拷贝。"
[[ -f "$BUNDLE_DIR/manifest.txt" ]] || die "找不到 manifest.txt；请确认整个离线包已拷贝。"
BUNDLE_ARCH="$(awk -F= '$1 == "arch" { print $2 }' "$BUNDLE_DIR/manifest.txt")"
[[ "$BUNDLE_ARCH" == "$NVIM_ARCH" ]] || die "离线包架构是 ${BUNDLE_ARCH:-unknown}，当前机器是 ${NVIM_ARCH}。"
# The manifest is authoritative for what was actually packaged.
BUNDLE_TMUX_VERSION="$(awk -F= '$1 == "tmux" { print $2 }' "$BUNDLE_DIR/manifest.txt")"
[[ -n "$BUNDLE_TMUX_VERSION" ]] || die "manifest.txt 缺少 tmux 版本。"
dev_env_validate_tmux_version "$BUNDLE_TMUX_VERSION" \
  || die "manifest.txt 的 tmux 版本不合法: ${BUNDLE_TMUX_VERSION}"
TMUX_VERSION="$BUNDLE_TMUX_VERSION"

FZF_ASSET="fzf-${FZF_VERSION}-linux_${FZF_ARCH}.tar.gz"
NVIM_ASSET="nvim-linux-${NVIM_ARCH}.tar.gz"
[[ -f "$BUNDLE_DIR/$FZF_ASSET" ]] || die "缺少 $FZF_ASSET"
[[ -f "$BUNDLE_DIR/$NVIM_ASSET" ]] || die "缺少 $NVIM_ASSET"
[[ -f "$BUNDLE_DIR/$TREE_SITTER_ASSET" ]] || die "缺少 $TREE_SITTER_ASSET"
[[ -f "$BUNDLE_DIR/$STARSHIP_ASSET" ]] || die "缺少 $STARSHIP_ASSET"
[[ -f "$BUNDLE_DIR/$NERD_FONT_ASSET" ]] || die "缺少 $NERD_FONT_ASSET"
[[ -f "$BUNDLE_DIR/tmux-bin" ]] || die "缺少 tmux-bin"
[[ -f "$BUNDLE_DIR/tmux-build-info.txt" ]] || die "缺少 tmux-build-info.txt"
[[ -d "$BUNDLE_DIR/debs" ]] || die "缺少 debs/ 目录"
[[ -d "$BUNDLE_DIR/nvim" ]] || die "缺少 nvim/ 配置目录"
[[ -d "$BUNDLE_DIR/tmux" ]] || die "缺少 tmux/ 配置目录"
[[ -d "$BUNDLE_DIR/shell" ]] || die "缺少 shell/ 配置目录"
[[ -f "$BUNDLE_DIR/lib/common.sh" ]] || die "缺少 lib/common.sh"
[[ -d "$BUNDLE_DIR/nvim-plugins" ]] || die "缺少 nvim-plugins/ 目录"
[[ -f "$BUNDLE_DIR/nvim-parser/latex.so" ]] || die "缺少 nvim-parser/latex.so"

log "校验离线包完整性..."
(
  cd "$BUNDLE_DIR"
  sha256sum -c SHA256SUMS
)

# ---------- 安装 deb ----------

mapfile -t DEB_FILES < <(find "$BUNDLE_DIR/debs" -maxdepth 1 -name '*.deb' -print | sort)
[[ "${#DEB_FILES[@]}" -gt 0 ]] || die "debs/ 中没有 .deb 文件。"

log "安装 ${#DEB_FILES[@]} 个 deb 包（离线）..."
# 依赖顺序可能让第一次 dpkg -i 返回非零；随后用 dpkg --configure -a 收尾
run_sudo env DEBIAN_FRONTEND=noninteractive dpkg -i "${DEB_FILES[@]}" || true
run_sudo env DEBIAN_FRONTEND=noninteractive dpkg --configure -a

for pkg in $APT_PACKAGES_OFFLINE; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    die "apt 包未正确安装: $pkg"
  fi
done
log "apt 包安装完成。"

# ---------- 安装 Neovim / fzf ----------

LOCAL_BIN="$HOME/.local/bin"
LOCAL_OPT="$HOME/.local/opt"
install -d "$LOCAL_BIN" "$LOCAL_OPT"

log "安装 fzf $FZF_VERSION ..."
FZF_PREFIX="$LOCAL_OPT/fzf-${FZF_VERSION}"
rm -rf "$FZF_PREFIX"
install -d "$FZF_PREFIX"
tar -xzf "$BUNDLE_DIR/$FZF_ASSET" -C "$FZF_PREFIX"
chmod +x "$FZF_PREFIX/fzf"
ln -sfn "$FZF_PREFIX/fzf" "$LOCAL_BIN/fzf"

log "安装 Neovim $NVIM_VERSION ..."
NVIM_PREFIX="$LOCAL_OPT/nvim-${NVIM_VERSION}"
rm -rf "$NVIM_PREFIX"
install -d "$NVIM_PREFIX"
tar -xzf "$BUNDLE_DIR/$NVIM_ASSET" -C "$NVIM_PREFIX" --strip-components=1
[[ -x "$NVIM_PREFIX/bin/nvim" ]] || die "Neovim 压缩包结构不符合预期。"
ln -sfn "$NVIM_PREFIX/bin/nvim" "$LOCAL_BIN/nvim"

log "安装 tree-sitter $TREE_SITTER_VERSION ..."
TS_PREFIX="$LOCAL_OPT/tree-sitter-${TREE_SITTER_VERSION}"
rm -rf "$TS_PREFIX"
install -d "$TS_PREFIX"
unzip -q -o "$BUNDLE_DIR/$TREE_SITTER_ASSET" -d "$TS_PREFIX"
chmod +x "$TS_PREFIX/tree-sitter"
ln -sfn "$TS_PREFIX/tree-sitter" "$LOCAL_BIN/tree-sitter"

log "安装 tmux $TMUX_VERSION ..."
TMUX_PREFIX="$LOCAL_OPT/tmux-${TMUX_VERSION}"
rm -rf "$TMUX_PREFIX"
install -d "$TMUX_PREFIX/bin"
install -m 755 "$BUNDLE_DIR/tmux-bin" "$TMUX_PREFIX/bin/tmux"
ln -sfn "$TMUX_PREFIX/bin/tmux" "$LOCAL_BIN/tmux"
TMUX_INSTALLED="$("$LOCAL_BIN/tmux" -V 2>/dev/null | awk '{print $2}')"
[[ "$TMUX_INSTALLED" == "$TMUX_VERSION" ]] \
  || die "离线包 tmux 版本是 ${TMUX_INSTALLED:-unknown}，期望 ${TMUX_VERSION}。"
if [[ -x /usr/bin/tmux ]]; then
  warn "系统仍存在 /usr/bin/tmux ($(/usr/bin/tmux -V 2>/dev/null))；dev_env 使用 $LOCAL_BIN/tmux，不自动卸载系统包。"
fi

# Ubuntu 的 fd 包提供 fdfind
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  ln -sfn "$(command -v fdfind)" "$LOCAL_BIN/fd"
  log "已创建 fd -> fdfind 链接: $LOCAL_BIN/fd"
fi

log "安装 Starship $STARSHIP_VERSION ..."
STARSHIP_PREFIX="$LOCAL_OPT/starship-${STARSHIP_VERSION}"
rm -rf "$STARSHIP_PREFIX"
install -d "$STARSHIP_PREFIX"
tar -xzf "$BUNDLE_DIR/$STARSHIP_ASSET" -C "$STARSHIP_PREFIX"
[[ -x "$STARSHIP_PREFIX/starship" ]] || die "Starship 压缩包结构不符合预期。"
ln -sfn "$STARSHIP_PREFIX/starship" "$LOCAL_BIN/starship"

log "安装 Nerd Font $NERD_FONT_VERSION ..."
install -d "$HOME/.local/share/fonts"
tar -xJf "$BUNDLE_DIR/$NERD_FONT_ASSET" -C "$HOME/.local/share/fonts" \
  MesloLGSNerdFont-Regular.ttf \
  MesloLGSNerdFont-Bold.ttf \
  MesloLGSNerdFont-Italic.ttf \
  MesloLGSNerdFont-BoldItalic.ttf
if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
fi

# ---------- 配置 ----------

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  # The extracted bundle may live in /tmp or ~/Downloads and be deleted after
  # installation. Keep the config it links to under XDG_DATA_HOME.
  CONFIG_ROOT="$(dev_env_stage_configs "$BUNDLE_DIR" "$DATA_HOME")"
  log "配置已复制到稳定目录: $CONFIG_ROOT"

  dev_env_deploy_nvim_config "$CONFIG_ROOT/nvim" "$XDG_CONFIG_HOME"
  dev_env_deploy_tmux_config "$CONFIG_ROOT/tmux/tmux.conf" "$XDG_CONFIG_HOME"
  if [[ "$SKIP_SHELL" -eq 0 ]]; then
    dev_env_deploy_shell_config "$CONFIG_ROOT/shell" "$XDG_CONFIG_HOME"
    dev_env_deploy_terminal_assets "$CONFIG_ROOT/shell" "$DATA_HOME"
  else
    log "已跳过 shell 配置链接（--skip-shell）。"
  fi

  # ---------- 离线插件与 latex parser ----------

  PLUGIN_DST="$DATA_HOME/nvim/lazy"
  PARSER_DST="$DATA_HOME/nvim/site/parser"
  install -d "$PLUGIN_DST" "$PARSER_DST"

  log "安装离线 Neovim 插件 ..."
  for name in lazy.nvim which-key.nvim gitsigns.nvim fzf-lua markview.nvim grug-far.nvim neo-tree.nvim nui.nvim plenary.nvim lazydev.nvim nvim-lspconfig catppuccin; do
    [[ -d "$BUNDLE_DIR/nvim-plugins/$name" ]] || die "离线包缺少插件目录: $name"
    rm -rf "${PLUGIN_DST:?}/$name"
    cp -a "$BUNDLE_DIR/nvim-plugins/$name" "$PLUGIN_DST/$name"
  done
  cp -a "$BUNDLE_DIR/nvim-parser/latex.so" "$PARSER_DST/latex.so"

  PATH="$LOCAL_BIN:$PATH" \
    NVIM_BIN="$LOCAL_BIN/nvim" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    XDG_DATA_HOME="$DATA_HOME" \
    bash "$CONFIG_ROOT/nvim/scripts/install-plugins.sh" --check
else
  log "已跳过 Neovim/tmux/shell 配置、插件和 parser（--skip-config）。"
fi

# ---------- 验证 ----------

hash -r
NVIM_BIN="$LOCAL_BIN/nvim"
[[ -x "$NVIM_BIN" ]] || NVIM_BIN="$(command -v nvim || true)"
[[ -n "$NVIM_BIN" ]] || die "找不到 nvim。"
FZF_BIN="$LOCAL_BIN/fzf"
[[ -x "$FZF_BIN" ]] || FZF_BIN="$(command -v fzf || true)"
[[ -n "$FZF_BIN" ]] || die "找不到 fzf。"

log "版本检查："
"$NVIM_BIN" --version | head -n 1
"$FZF_BIN" --version
rg --version | head -n 1
if command -v fd >/dev/null 2>&1; then
  fd --version
elif [[ -x "$LOCAL_BIN/fd" ]]; then
  "$LOCAL_BIN/fd" --version
fi
git --version
"$LOCAL_BIN/tree-sitter" --version
"$LOCAL_BIN/tmux" -V
zsh --version
"$LOCAL_BIN/starship" --version

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  log "Neovim 配置冒烟测试："
  if ! PATH="$LOCAL_BIN:$PATH" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    XDG_DATA_HOME="$DATA_HOME" \
    "$NVIM_BIN" --headless \
    "+lua if vim.o.number ~= true or vim.o.relativenumber ~= true or vim.o.mouse ~= 'a' or vim.g.colors_name ~= 'catppuccin-mocha' then error('Neovim config smoke test failed') end" \
    +qa; then
    die "Neovim 配置加载失败；请检查 $XDG_CONFIG_HOME/nvim。"
  fi
fi

case ":$PATH:" in
  *":$LOCAL_BIN:"*) ;;
  *)
    warn "当前 PATH 不包含 ${LOCAL_BIN}。"
    if [[ "$SKIP_CONFIG" -eq 0 && "$SKIP_SHELL" -eq 0 ]]; then
      warn "dev_env shell 配置已链接；新开 zsh 后会自动把 ~/.local/bin 放到 PATH 前面。"
    else
      warn "请重新登录，或把下面一行加入 ~/.profile / ~/.zshrc："
      warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    ;;
esac

if command -v zsh >/dev/null 2>&1 && [[ "$(getent passwd "$(id -un)" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
  warn "当前登录 shell 不是 zsh。如需默认使用 zsh，请手动执行："
  warn "  chsh -s $(command -v zsh)"
fi

log "离线安装完成。"
log "启动 Neovim: nvim"
log "tmux 配置: ${XDG_CONFIG_HOME}/tmux/tmux.conf"
if [[ "$SKIP_CONFIG" -eq 0 && "$SKIP_SHELL" -eq 0 ]]; then
  log "shell 配置: ~/.zshrc -> $CONFIG_ROOT/shell/zshrc"
  log "本地覆盖: ~/.zshrc.local（已存在则未改动）"
fi
log "配置目录: ${XDG_CONFIG_HOME}/nvim"
if [[ -n "$CONFIG_ROOT" ]]; then
  log "稳定配置副本: ${CONFIG_ROOT}（删除解压后的离线包不会影响配置）"
fi

#!/usr/bin/env bash
#
# macOS 开发环境安装脚本（联网版）
#
# 安装内容：
#   - Neovim 0.12.x、fzf、tree-sitter、Starship（官方 tarball，用户目录安装）
#   - ripgrep、fd、git、tmux（Homebrew，仅在缺失时安装；可 --pinned-tmux）
#   - Meslo Nerd Font
#   - 把 dev_env/nvim、dev_env/tmux、dev_env/shell 链接到用户配置目录
#
# 用法：
#   bash platforms/macos/install.sh
#   bash platforms/macos/install.sh --skip-config
#
set -euo pipefail

SKIP_CONFIG=0
SKIP_SHELL=0
PINNED_TMUX=0

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
. "$SCRIPT_DIR/versions.env"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
NVIM_CONFIG_SRC="$REPO_ROOT/nvim"
TMUX_CONFIG_SRC="$REPO_ROOT/tmux/tmux.conf"
SHELL_CONFIG_SRC="$REPO_ROOT/shell"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
NVIM_CONFIG_DST="$XDG_CONFIG_HOME/nvim"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_OPT="$HOME/.local/opt"
TMP_DIR=""

log()  { printf '\033[1;32m[dev_env]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[dev_env]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[dev_env]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
用法: install.sh [选项]

选项:
  --skip-config   只安装工具，不链接 Neovim/tmux/shell 配置
  --skip-shell    只跳过 shell 配置链接
  --pinned-tmux   用固定版本源码构建自包含 tmux（需要 Xcode CLT）
  -h, --help      显示帮助

要求:
  - macOS
  - 已安装 Homebrew（用于 ripgrep / fd / git / tmux）
EOF
}

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

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
    --pinned-tmux)
      PINNED_TMUX=1
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
if [[ "${EUID}" -eq 0 ]]; then
  die "请不要用 root/sudo 运行；Homebrew 也不建议以 root 使用。"
fi
command -v brew >/dev/null 2>&1 || die "找不到 Homebrew，请先安装：https://brew.sh/"
[[ -f "$NVIM_CONFIG_SRC/init.lua" ]] || die "找不到 Neovim 配置: $NVIM_CONFIG_SRC/init.lua"
[[ -f "$TMUX_CONFIG_SRC" ]] || die "找不到 tmux 配置: $TMUX_CONFIG_SRC"
[[ -f "$SHELL_CONFIG_SRC/zshrc" ]] || die "找不到 shell 配置: $SHELL_CONFIG_SRC/zshrc"

case "$(uname -m)" in
  arm64)
    NVIM_ASSET="nvim-macos-arm64.tar.gz"
    FZF_ASSET="fzf-${FZF_VERSION}-darwin_arm64.tar.gz"
    TREE_SITTER_ASSET="tree-sitter-cli-macos-arm64.zip"
    STARSHIP_ASSET="starship-aarch64-apple-darwin.tar.gz"
    NVIM_SHA256="$NVIM_SHA256_ARM64"
    FZF_SHA256="$FZF_SHA256_ARM64"
    TREE_SITTER_SHA256="$TREE_SITTER_SHA256_ARM64"
    STARSHIP_SHA256="$STARSHIP_SHA256_ARM64"
    ;;
  x86_64)
    NVIM_ASSET="nvim-macos-x86_64.tar.gz"
    FZF_ASSET="fzf-${FZF_VERSION}-darwin_amd64.tar.gz"
    TREE_SITTER_ASSET="tree-sitter-cli-macos-x64.zip"
    STARSHIP_ASSET="starship-x86_64-apple-darwin.tar.gz"
    NVIM_SHA256="$NVIM_SHA256_X86_64"
    FZF_SHA256="$FZF_SHA256_X86_64"
    TREE_SITTER_SHA256="$TREE_SITTER_SHA256_X86_64"
    STARSHIP_SHA256="$STARSHIP_SHA256_X86_64"
    ;;
  *)
    die "不支持的 CPU 架构: $(uname -m)"
    ;;
esac

# ---------- Homebrew 工具 ----------

ensure_brew_tool() {
  local cmd="$1"
  local pkg="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    log "$cmd 已存在: $(command -v "$cmd")"
  else
    log "brew install $pkg ..."
    brew install "$pkg"
  fi
}

ensure_brew_tool rg ripgrep
ensure_brew_tool fd fd
ensure_brew_tool git git
ensure_brew_tool node node

# ---------- Neovim / fzf ----------

download_verify() {
  local url="$1"
  local dest="$2"
  local expected="$3"
  local actual

  curl -fL --http1.1 --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 15 "$url" -o "$dest"
  actual="$(shasum -a 256 "$dest" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    die "校验失败: ${dest}（期望 ${expected}，实际 ${actual}）"
  fi
}

nvim_current_version() {
  if [[ -x "$LOCAL_BIN/nvim" ]]; then
    "$LOCAL_BIN/nvim" --version 2>/dev/null | head -n 1 | sed 's/^NVIM v//'
    return
  fi
  command -v nvim >/dev/null 2>&1 || return 1
  nvim --version 2>/dev/null | head -n 1 | sed 's/^NVIM v//'
}

fzf_current_version() {
  if [[ -x "$LOCAL_BIN/fzf" ]]; then
    "$LOCAL_BIN/fzf" --version 2>/dev/null | awk '{print $1}'
    return
  fi
  command -v fzf >/dev/null 2>&1 || return 1
  fzf --version 2>/dev/null | awk '{print $1}'
}

CURRENT_NVIM="$(nvim_current_version || true)"
if [[ "$CURRENT_NVIM" == "$NVIM_VERSION" ]]; then
  log "Neovim 已是 ${NVIM_VERSION}，跳过。"
else
  install -d "$LOCAL_BIN" "$LOCAL_OPT"
  TMP_DIR="$(mktemp -d)"
  NVIM_PREFIX="$LOCAL_OPT/nvim-${NVIM_VERSION}"
  log "下载 Neovim ${NVIM_VERSION} ..."
  download_verify \
    "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/${NVIM_ASSET}" \
    "$TMP_DIR/$NVIM_ASSET" \
    "$NVIM_SHA256"
  rm -rf "$NVIM_PREFIX"
  install -d "$NVIM_PREFIX"
  tar -xzf "$TMP_DIR/$NVIM_ASSET" -C "$NVIM_PREFIX" --strip-components=1
  [[ -x "$NVIM_PREFIX/bin/nvim" ]] || die "Neovim 压缩包结构不符合预期。"
  ln -sfn "$NVIM_PREFIX/bin/nvim" "$LOCAL_BIN/nvim"
  log "Neovim 已安装: $LOCAL_BIN/nvim"
fi

CURRENT_FZF="$(fzf_current_version || true)"
if [[ "$CURRENT_FZF" == "$FZF_VERSION" ]]; then
  log "fzf 已是 ${FZF_VERSION}，跳过。"
else
  install -d "$LOCAL_BIN" "$LOCAL_OPT"
  if [[ -z "$TMP_DIR" ]]; then
    TMP_DIR="$(mktemp -d)"
  fi
  FZF_PREFIX="$LOCAL_OPT/fzf-${FZF_VERSION}"
  log "下载 fzf ${FZF_VERSION} ..."
  download_verify \
    "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/${FZF_ASSET}" \
    "$TMP_DIR/$FZF_ASSET" \
    "$FZF_SHA256"
  rm -rf "$FZF_PREFIX"
  install -d "$FZF_PREFIX"
  tar -xzf "$TMP_DIR/$FZF_ASSET" -C "$FZF_PREFIX"
  chmod +x "$FZF_PREFIX/fzf"
  ln -sfn "$FZF_PREFIX/fzf" "$LOCAL_BIN/fzf"
  log "fzf 已安装: $LOCAL_BIN/fzf"
fi

# ---------- tree-sitter ----------

install_tree_sitter() {
  local asset="$TREE_SITTER_ASSET"
  local prefix="$LOCAL_OPT/tree-sitter-${TREE_SITTER_VERSION}"
  if [[ -z "$TMP_DIR" ]]; then
    TMP_DIR="$(mktemp -d)"
  fi
  log "下载 tree-sitter ${TREE_SITTER_VERSION} ..."
  download_verify \
    "https://github.com/tree-sitter/tree-sitter/releases/download/v${TREE_SITTER_VERSION}/${asset}" \
    "$TMP_DIR/$asset" \
    "$TREE_SITTER_SHA256"
  rm -rf "$prefix"
  install -d "$prefix"
  unzip -q -o "$TMP_DIR/$asset" -d "$prefix"
  chmod +x "$prefix/tree-sitter"
  ln -sfn "$prefix/tree-sitter" "$LOCAL_BIN/tree-sitter"
  log "tree-sitter 已安装: $LOCAL_BIN/tree-sitter"
}

install -d "$LOCAL_BIN" "$LOCAL_OPT"

if [[ -x "$LOCAL_BIN/tree-sitter" ]] && "$LOCAL_BIN/tree-sitter" --version 2>/dev/null | grep -q "$TREE_SITTER_VERSION"; then
  log "tree-sitter ${TREE_SITTER_VERSION} 已存在，跳过。"
else
  install_tree_sitter
fi

# ---------- tmux ----------

tmux_current_version() {
  if [[ -x "$LOCAL_BIN/tmux" ]]; then
    "$LOCAL_BIN/tmux" -V 2>/dev/null | awk '{print $2}'
    return
  fi
  command -v tmux >/dev/null 2>&1 || return 1
  tmux -V 2>/dev/null | awk '{print $2}'
}

install_pinned_tmux() {
  local out
  local prefix="$LOCAL_OPT/tmux-${TMUX_VERSION}"

  if [[ -z "$TMP_DIR" ]]; then
    TMP_DIR="$(mktemp -d)"
  fi
  out="$TMP_DIR/tmux-build"
  rm -rf "$out"
  install -d "$out"
  log "构建自包含 tmux ${TMUX_VERSION} ..."
  bash "$SCRIPT_DIR/scripts/build-tmux.sh" --output "$out"
  rm -rf "$prefix"
  install -d "$prefix/bin"
  install -m 755 "$out/tmux" "$prefix/bin/tmux"
  ln -sfn "$prefix/bin/tmux" "$LOCAL_BIN/tmux"
  log "tmux 已安装: $LOCAL_BIN/tmux"
}

if [[ "$PINNED_TMUX" -eq 1 ]]; then
  if [[ "$(tmux_current_version || true)" == "$TMUX_VERSION" && -x "$LOCAL_BIN/tmux" ]]; then
    log "pinned tmux ${TMUX_VERSION} 已存在，跳过构建。"
  else
    install -d "$LOCAL_BIN" "$LOCAL_OPT"
    install_pinned_tmux
  fi
else
  ensure_brew_tool tmux tmux
fi

# ---------- Starship / Nerd Font ----------

starship_current_version() {
  if [[ -x "$LOCAL_BIN/starship" ]]; then
    "$LOCAL_BIN/starship" --version 2>/dev/null | awk '{print $2}'
    return
  fi
  command -v starship >/dev/null 2>&1 || return 1
  starship --version 2>/dev/null | awk '{print $2}'
}

install_starship() {
  local prefix="$LOCAL_OPT/starship-${STARSHIP_VERSION}"
  local asset="$STARSHIP_ASSET"

  if [[ -z "$TMP_DIR" ]]; then
    TMP_DIR="$(mktemp -d)"
  fi
  download_verify \
    "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/${asset}" \
    "$TMP_DIR/$asset" \
    "$STARSHIP_SHA256"
  rm -rf "$prefix"
  install -d "$prefix"
  tar -xzf "$TMP_DIR/$asset" -C "$prefix"
  [[ -x "$prefix/starship" ]] || die "Starship 压缩包结构不符合预期。"
  ln -sfn "$prefix/starship" "$LOCAL_BIN/starship"
  log "Starship 已安装: $LOCAL_BIN/starship"
}

CURRENT_STARSHIP="$(starship_current_version || true)"
if [[ "$CURRENT_STARSHIP" == "$STARSHIP_VERSION" ]]; then
  log "Starship 已是 ${STARSHIP_VERSION}，跳过。"
else
  install -d "$LOCAL_BIN" "$LOCAL_OPT"
  install_starship
fi

install_nerd_font() {
  local asset="$NERD_FONT_ASSET"
  local font_files=(
    MesloLGSNerdFont-Regular.ttf
    MesloLGSNerdFont-Bold.ttf
    MesloLGSNerdFont-Italic.ttf
    MesloLGSNerdFont-BoldItalic.ttf
  )

  if [[ -z "$TMP_DIR" ]]; then
    TMP_DIR="$(mktemp -d)"
  fi
  download_verify \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONT_VERSION}/${asset}" \
    "$TMP_DIR/$asset" \
    "$NERD_FONT_SHA256"
  install -d "$HOME/Library/Fonts"
  tar -xJf "$TMP_DIR/$asset" -C "$HOME/Library/Fonts" "${font_files[@]}"
  log "Nerd Font 已安装到 $HOME/Library/Fonts"
}

install_nerd_font

# ---------- 配置 ----------

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  dev_env_deploy_nvim_config "$NVIM_CONFIG_SRC" "$XDG_CONFIG_HOME"
  dev_env_deploy_tmux_config "$TMUX_CONFIG_SRC" "$XDG_CONFIG_HOME"
  if [[ "$SKIP_SHELL" -eq 0 ]]; then
    dev_env_deploy_shell_config "$SHELL_CONFIG_SRC" "$XDG_CONFIG_HOME"
    dev_env_deploy_terminal_assets "$SHELL_CONFIG_SRC" "${XDG_DATA_HOME:-$HOME/.local/share}"
  else
    log "已跳过 shell 配置链接（--skip-shell）。"
  fi
else
  log "已跳过 Neovim/tmux/shell 配置链接（--skip-config）。"
fi

# ---------- 验证 ----------

hash -r

NVIM_BIN="$LOCAL_BIN/nvim"
if [[ ! -x "$NVIM_BIN" ]]; then
  NVIM_BIN="$(command -v nvim || true)"
fi
[[ -n "$NVIM_BIN" ]] || die "找不到 nvim 可执行文件。"

FZF_BIN="$LOCAL_BIN/fzf"
if [[ ! -x "$FZF_BIN" ]]; then
  FZF_BIN="$(command -v fzf || true)"
fi
[[ -n "$FZF_BIN" ]] || die "找不到 fzf 可执行文件。"

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  log "安装 Neovim 插件 ..."
  PATH="$LOCAL_BIN:$PATH" \
    NVIM_BIN="$NVIM_BIN" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" \
    bash "$NVIM_CONFIG_SRC/scripts/install-plugins.sh"
  log "编译 latex Tree-sitter parser ..."
  PATH="$LOCAL_BIN:$PATH" \
    NVIM_BIN="$NVIM_BIN" \
    XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" \
    bash "$NVIM_CONFIG_SRC/scripts/build-latex-parser.sh"
fi

TMUX_BIN="$LOCAL_BIN/tmux"
if [[ ! -x "$TMUX_BIN" ]]; then
  TMUX_BIN="$(command -v tmux || true)"
fi
[[ -n "$TMUX_BIN" ]] || die "找不到 tmux 可执行文件。"

STARSHIP_BIN="$LOCAL_BIN/starship"
if [[ ! -x "$STARSHIP_BIN" ]]; then
  STARSHIP_BIN="$(command -v starship || true)"
fi
[[ -n "$STARSHIP_BIN" ]] || die "找不到 starship 可执行文件。"

log "版本检查："
"$NVIM_BIN" --version | head -n 1
"$FZF_BIN" --version
rg --version | head -n 1
fd --version
git --version
"$LOCAL_BIN/tree-sitter" --version
"$TMUX_BIN" -V
zsh --version
"$STARSHIP_BIN" --version

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  log "Neovim 配置冒烟测试："
  if ! PATH="$LOCAL_BIN:$PATH" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" \
    "$NVIM_BIN" --headless \
    "+lua if vim.o.number ~= true or vim.o.relativenumber ~= true or vim.o.mouse ~= 'a' or vim.g.colors_name ~= 'catppuccin-mocha' then error('Neovim config smoke test failed') end" \
    +qa; then
    die "Neovim 配置加载失败，请检查 ${NVIM_CONFIG_DST}。"
  fi
fi

case ":$PATH:" in
  *":$LOCAL_BIN:"*) ;;
  *)
    warn "当前 PATH 不包含 ${LOCAL_BIN}。"
    if [[ "$SKIP_CONFIG" -eq 0 && "$SKIP_SHELL" -eq 0 ]]; then
      warn "dev_env shell 配置已链接；新开 zsh 后会自动把 ~/.local/bin 放到 PATH 前面。"
    else
      warn "请重新登录，或把下面一行加入 ~/.zshrc："
      warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    ;;
esac

log "完成。"
log "启动 Neovim: nvim"
log "tmux 配置: ${XDG_CONFIG_HOME}/tmux/tmux.conf"
if [[ "$SKIP_CONFIG" -eq 0 && "$SKIP_SHELL" -eq 0 ]]; then
  log "shell 配置: ~/.zshrc -> $SHELL_CONFIG_SRC/zshrc"
  log "本地覆盖: ~/.zshrc.local（已存在则未改动）"
fi
log "配置源文件: $NVIM_CONFIG_SRC/init.lua"

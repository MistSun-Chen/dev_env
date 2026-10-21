#!/usr/bin/env bash
#
# macOS 开发环境安装脚本（联网版）
#
# 安装内容：
#   - Neovim 0.12.x（官方 macOS tarball，用户目录安装）
#   - fzf（官方 macOS tarball，用户目录安装）
#   - ripgrep、fd、git（Homebrew，仅在缺失时安装）
#   - 把 dev_env/nvim 链接到 Neovim 配置目录
#
# 用法：
#   bash platforms/macos/install.sh
#   bash platforms/macos/install.sh --skip-config
#
set -euo pipefail

SKIP_CONFIG=0

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
. "$SCRIPT_DIR/versions.env"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
NVIM_CONFIG_SRC="$REPO_ROOT/nvim"
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
  --skip-config   只安装工具，不链接 Neovim 配置
  -h, --help      显示帮助

要求:
  - macOS
  - 已安装 Homebrew（用于 ripgrep / fd / git）
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

case "$(uname -m)" in
  arm64)
    FZF_ARCH="arm64"
    NVIM_ASSET="nvim-macos-arm64.tar.gz"
    FZF_ASSET="fzf-${FZF_VERSION}-darwin_arm64.tar.gz"
    MERMAID_ASCII_ASSET="mermaid-ascii_Darwin_arm64.tar.gz"
    TREE_SITTER_ASSET="tree-sitter-cli-macos-arm64.zip"
    NVIM_SHA256="$NVIM_SHA256_ARM64"
    FZF_SHA256="$FZF_SHA256_ARM64"
    MERMAID_ASCII_SHA256="$MERMAID_ASCII_SHA256_ARM64"
    TREE_SITTER_SHA256="$TREE_SITTER_SHA256_ARM64"
    ;;
  x86_64)
    FZF_ARCH="amd64"
    NVIM_ASSET="nvim-macos-x86_64.tar.gz"
    FZF_ASSET="fzf-${FZF_VERSION}-darwin_amd64.tar.gz"
    MERMAID_ASCII_ASSET="mermaid-ascii_Darwin_x86_64.tar.gz"
    TREE_SITTER_ASSET="tree-sitter-cli-macos-x64.zip"
    NVIM_SHA256="$NVIM_SHA256_X86_64"
    FZF_SHA256="$FZF_SHA256_X86_64"
    MERMAID_ASCII_SHA256="$MERMAID_ASCII_SHA256_X86_64"
    TREE_SITTER_SHA256="$TREE_SITTER_SHA256_X86_64"
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

# ---------- mermaid-ascii / tree-sitter ----------

install_mermaid_ascii() {
  local asset="$MERMAID_ASCII_ASSET"
  local prefix="$LOCAL_OPT/mermaid-ascii-${MERMAID_ASCII_VERSION}"
  if [[ -z "$TMP_DIR" ]]; then
    TMP_DIR="$(mktemp -d)"
  fi
  log "下载 mermaid-ascii ${MERMAID_ASCII_VERSION} ..."
  download_verify \
    "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/${MERMAID_ASCII_VERSION}/${asset}" \
    "$TMP_DIR/$asset" \
    "$MERMAID_ASCII_SHA256"
  rm -rf "$prefix"
  install -d "$prefix"
  tar -xzf "$TMP_DIR/$asset" -C "$prefix"
  chmod +x "$prefix/mermaid-ascii"
  ln -sfn "$prefix/mermaid-ascii" "$LOCAL_BIN/mermaid-ascii"
  log "mermaid-ascii 已安装: $LOCAL_BIN/mermaid-ascii"
}

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

if [[ -x "$LOCAL_BIN/mermaid-ascii" ]] && "$LOCAL_BIN/mermaid-ascii" --help >/dev/null 2>&1; then
  log "mermaid-ascii 已存在，跳过。"
else
  install_mermaid_ascii
fi

if [[ -x "$LOCAL_BIN/tree-sitter" ]] && "$LOCAL_BIN/tree-sitter" --version 2>/dev/null | grep -q "$TREE_SITTER_VERSION"; then
  log "tree-sitter ${TREE_SITTER_VERSION} 已存在，跳过。"
else
  install_tree_sitter
fi

# ---------- Neovim 配置 ----------

deploy_nvim_config() {
  install -d "$(dirname "$NVIM_CONFIG_DST")"

  if [[ -L "$NVIM_CONFIG_DST" ]]; then
    local current
    current="$(readlink -f "$NVIM_CONFIG_DST" || true)"
    if [[ "$current" == "$(readlink -f "$NVIM_CONFIG_SRC")" ]]; then
      log "Neovim 配置已经链接到仓库，跳过。"
      return
    fi
  fi

  if [[ -e "$NVIM_CONFIG_DST" || -L "$NVIM_CONFIG_DST" ]]; then
    local backup="${NVIM_CONFIG_DST}.bak.$(date +%Y%m%d-%H%M%S)"
    while [[ -e "$backup" || -L "$backup" ]]; do
      backup="${backup}-$$"
    done
    mv "$NVIM_CONFIG_DST" "$backup"
    log "已备份旧 Neovim 配置: $backup"
  fi

  ln -sfn "$NVIM_CONFIG_SRC" "$NVIM_CONFIG_DST"
  log "已链接 Neovim 配置: $NVIM_CONFIG_DST -> $NVIM_CONFIG_SRC"
}

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  deploy_nvim_config
else
  log "已跳过 Neovim 配置链接（--skip-config）。"
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

log "版本检查："
"$NVIM_BIN" --version | head -n 1
"$FZF_BIN" --version
rg --version | head -n 1
fd --version
git --version
"$LOCAL_BIN/mermaid-ascii" --help >/dev/null && echo "mermaid-ascii ${MERMAID_ASCII_VERSION}"
"$LOCAL_BIN/tree-sitter" --version

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  log "Neovim 配置冒烟测试："
  if ! "$NVIM_BIN" --headless \
    "+lua print('number='..tostring(vim.o.number)..' relativenumber='..tostring(vim.o.relativenumber)..' mouse='..vim.o.mouse)" \
    +qa; then
    warn "Neovim 配置加载失败，请检查 ${NVIM_CONFIG_DST}。"
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

log "完成。"
log "启动 Neovim: nvim"
log "配置源文件: $NVIM_CONFIG_SRC/init.lua"

#!/usr/bin/env bash
#
# Ubuntu 24.04 开发环境安装脚本
#
# 安装内容：
#   - Neovim 0.12.x、fzf、tree-sitter、Starship（官方 tarball，用户目录安装）
#   - tmux 3.8（自包含源码构建；不使用 Ubuntu 源里的 3.4）
#   - zsh、ncurses-term、xz-utils（apt）
#   - ripgrep、fd（Ubuntu 包名为 fd-find，脚本会补一个 fd 命令）
#   - git / curl / ca-certificates / gcc / libc6-dev / make / bison / libncurses-dev / file / binutils
#   - Neovim 插件与 latex parser
#   - Meslo Nerd Font
#   - 把 dev_env/nvim、dev_env/tmux、dev_env/shell 链接到用户配置目录
#
# 设计原则：
#   - 不使用 Ubuntu 源里的 neovim（24.04 只有 0.9.5，太旧，不支持当前配置）
#   - 不使用 Ubuntu 源里的 fzf（24.04 是 0.44.1，部分 picker 功能需要更新版本）
#   - 用户目录安装，尽量少污染系统；只在 apt 安装时使用 sudo
#   - 可重复执行；已有配置会先备份
#
# 用法：
#   bash platforms/linux/ubuntu/24.04/install.sh
#   bash platforms/linux/ubuntu/24.04/install.sh --skip-config
#   NVIM_VERSION=0.12.3 FZF_VERSION=0.74.5 bash platforms/linux/ubuntu/24.04/install.sh
#
set -euo pipefail

SKIP_CONFIG=0
SKIP_SHELL=0
ALLOW_ROOT=0
SUDO=""

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
. "$SCRIPT_DIR/versions.env"
# shellcheck source=../../../lib/common.sh
. "$SCRIPT_DIR/../../../lib/common.sh"
NVIM_SHA256="${NVIM_SHA256:-}"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
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

可通过环境变量覆盖版本:
  NVIM_VERSION=0.12.3
  FZF_VERSION=0.74.5
  NVIM_SHA256=<sha256>    # 覆盖 Neovim 版本时必须提供
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

# ---------- 基本检查 ----------

if [[ "${EUID}" -eq 0 ]]; then
  if [[ "$ALLOW_ROOT" -ne 1 ]]; then
    die "请不要直接用 root 或 sudo 运行整个脚本；脚本会在需要时调用 sudo。容器/CI 中可加 --allow-root。"
  fi
  SUDO=""
else
  command -v sudo >/dev/null 2>&1 || die "需要 sudo 来安装 apt 包。"
  SUDO="sudo"
fi

[[ -r /etc/os-release ]] || die "无法读取 /etc/os-release，脚本只支持 Ubuntu 24.04。"

# shellcheck disable=SC1091
. /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
  die "当前系统不是 Ubuntu（ID=${ID:-unknown}）。"
fi

if [[ "${VERSION_ID:-}" != "24.04" ]]; then
  warn "当前 Ubuntu 版本是 ${VERSION_ID:-unknown}，脚本按 24.04 编写，继续执行可能不兼容。"
fi

command -v apt-get >/dev/null 2>&1 || die "找不到 apt-get。"

case "$(uname -m)" in
  x86_64|amd64)
    FZF_ARCH="amd64"
    NVIM_ARCH="x86_64"
    TREE_SITTER_ASSET="tree-sitter-cli-linux-x64.zip"
    STARSHIP_ASSET="starship-x86_64-unknown-linux-musl.tar.gz"
    TREE_SITTER_SHA256="$TREE_SITTER_SHA256_X86_64"
    STARSHIP_SHA256="$STARSHIP_SHA256_X86_64"
    ;;
  aarch64|arm64)
    FZF_ARCH="arm64"
    NVIM_ARCH="arm64"
    TREE_SITTER_ASSET="tree-sitter-cli-linux-arm64.zip"
    STARSHIP_ASSET="starship-aarch64-unknown-linux-musl.tar.gz"
    TREE_SITTER_SHA256="$TREE_SITTER_SHA256_ARM64"
    STARSHIP_SHA256="$STARSHIP_SHA256_ARM64"
    ;;
  *)
    die "不支持的 CPU 架构: $(uname -m)"
    ;;
esac

# 默认版本 0.12.3 的官方 tarball 校验和；覆盖版本时可通过 NVIM_SHA256 传入
if [[ -z "$NVIM_SHA256" && "$NVIM_VERSION" == "0.12.3" ]]; then
  case "$NVIM_ARCH" in
    x86_64) NVIM_SHA256="$NVIM_SHA256_X86_64" ;;
    arm64)  NVIM_SHA256="$NVIM_SHA256_ARM64" ;;
  esac
fi

[[ -f "$NVIM_CONFIG_SRC/init.lua" ]] || die "找不到 Neovim 配置: $NVIM_CONFIG_SRC/init.lua"
[[ -f "$TMUX_CONFIG_SRC" ]] || die "找不到 tmux 配置: $TMUX_CONFIG_SRC"
[[ -f "$SHELL_CONFIG_SRC/zshrc" ]] || die "找不到 shell 配置: $SHELL_CONFIG_SRC/zshrc"

# 先刷新一次 sudo 凭据，避免后面多次输入密码
if [[ -n "$SUDO" ]]; then
  "$SUDO" -v
fi

# ---------- 系统包 ----------

APT_OPTS=(
  -o Acquire::ForceIPv4=true
  -o Acquire::http::Timeout=30
  -o Acquire::https::Timeout=30
  -o Acquire::Retries=3
  -o Acquire::http::Pipeline-Depth=0
)

log "更新 apt 索引..."
run_sudo apt-get "${APT_OPTS[@]}" update

read -r -a APT_PACKAGE_ARRAY <<< "$APT_PACKAGES"
log "安装系统包：${APT_PACKAGES}..."
run_sudo env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" install -y --no-install-recommends \
  "${APT_PACKAGE_ARRAY[@]}"

# Ubuntu 的 fd 包提供的是 fdfind；补一个 fd 命令，方便插件和脚本统一调用
install -d "$LOCAL_BIN"
if ! command -v fd >/dev/null 2>&1; then
  if command -v fdfind >/dev/null 2>&1; then
    ln -sfn "$(command -v fdfind)" "$LOCAL_BIN/fd"
    log "已创建 fd -> fdfind 链接: $LOCAL_BIN/fd"
  else
    warn "已安装 fd-find，但没有找到 fdfind 命令。"
  fi
fi

# ---------- fzf ----------

fzf_current_version() {
  if [[ -x "$LOCAL_BIN/fzf" ]]; then
    "$LOCAL_BIN/fzf" --version 2>/dev/null | awk '{print $1}'
    return
  fi
  command -v fzf >/dev/null 2>&1 || return 1
  fzf --version 2>/dev/null | awk '{print $1}'
}

install_fzf() {
  local asset="fzf-${FZF_VERSION}-linux_${FZF_ARCH}.tar.gz"
  local base_url="https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}"
  local prefix="$LOCAL_OPT/fzf-${FZF_VERSION}"
  local checksum_file="$TMP_DIR/fzf-checksums.txt"

  log "下载 fzf ${FZF_VERSION}（${FZF_ARCH}）..."
  curl -fL --http1.1 --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 15 \
    "$base_url/$asset" -o "$TMP_DIR/$asset"
  curl -fL --http1.1 --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 15 \
    "$base_url/fzf_${FZF_VERSION}_checksums.txt" -o "$checksum_file"

  if ! grep -qE "[[:space:]]${asset}$" "$checksum_file"; then
    die "校验文件中找不到 ${asset}，停止安装。"
  fi
  if ! grep -E "[[:space:]]${asset}$" "$checksum_file" | (cd "$TMP_DIR" && sha256sum -c -); then
    die "fzf 校验失败，停止安装。"
  fi

  rm -rf "$prefix"
  install -d "$prefix"
  tar -xzf "$TMP_DIR/$asset" -C "$prefix"
  chmod +x "$prefix/fzf"
  ln -sfn "$prefix/fzf" "$LOCAL_BIN/fzf"

  log "fzf 已安装: $LOCAL_BIN/fzf"
}

CURRENT_FZF="$(fzf_current_version || true)"
if [[ "$CURRENT_FZF" == "$FZF_VERSION" ]]; then
  log "fzf 已是 ${FZF_VERSION}，跳过。"
else
  install -d "$LOCAL_BIN" "$LOCAL_OPT"
  TMP_DIR="$(mktemp -d)"
  install_fzf
fi

# ---------- tree-sitter ----------

download_verify() {
  local url="$1"
  local dest="$2"
  local expected="$3"
  local actual

  curl -fL --http1.1 --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 15 "$url" -o "$dest"
  actual="$(sha256sum "$dest" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    die "校验失败: ${dest}（期望 ${expected}，实际 ${actual}）"
  fi
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

if [[ -x "$LOCAL_BIN/tree-sitter" ]] && "$LOCAL_BIN/tree-sitter" --version 2>/dev/null | grep -q "$TREE_SITTER_VERSION"; then
  log "tree-sitter ${TREE_SITTER_VERSION} 已存在，跳过。"
else
  install_tree_sitter
fi

# ---------- tmux / Starship / Nerd Font ----------

tmux_current_version() {
  if [[ -x "$LOCAL_BIN/tmux" ]]; then
    "$LOCAL_BIN/tmux" -V 2>/dev/null | awk '{print $2}'
    return
  fi
  command -v tmux >/dev/null 2>&1 || return 1
  tmux -V 2>/dev/null | awk '{print $2}'
}

install_pinned_tmux() {
  local installed
  local out
  local prefix

  dev_env_validate_tmux_version "$TMUX_VERSION" \
    || die "tmux 版本不合法: ${TMUX_VERSION}"
  prefix="$LOCAL_OPT/tmux-${TMUX_VERSION}"

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
  installed="$("$LOCAL_BIN/tmux" -V 2>/dev/null | awk '{print $2}')"
  [[ "$installed" == "$TMUX_VERSION" ]] \
    || die "自包含 tmux 版本是 ${installed:-unknown}，期望 ${TMUX_VERSION}。"
  log "tmux 已安装: $LOCAL_BIN/tmux (${installed})"
}

if [[ "$(tmux_current_version || true)" == "$TMUX_VERSION" && -x "$LOCAL_BIN/tmux" ]]; then
  log "pinned tmux ${TMUX_VERSION} 已存在，跳过构建。"
else
  install -d "$LOCAL_BIN" "$LOCAL_OPT"
  install_pinned_tmux
fi

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
  install -d "$HOME/.local/share/fonts"
  tar -xJf "$TMP_DIR/$asset" -C "$HOME/.local/share/fonts" "${font_files[@]}"
  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
  else
    warn "找不到 fc-cache；字体已复制，但可能需要手动刷新字体缓存。"
  fi
  log "Nerd Font 已安装到 $HOME/.local/share/fonts"
}

install_nerd_font

# ---------- Neovim ----------

nvim_current_version() {
  if [[ -x "$LOCAL_BIN/nvim" ]]; then
    "$LOCAL_BIN/nvim" --version 2>/dev/null | head -n 1 | sed 's/^NVIM v//'
    return
  fi
  command -v nvim >/dev/null 2>&1 || return 1
  nvim --version 2>/dev/null | head -n 1 | sed 's/^NVIM v//'
}

install_neovim() {
  local asset="nvim-linux-${NVIM_ARCH}.tar.gz"
  local url="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/${asset}"
  local prefix="$LOCAL_OPT/nvim-${NVIM_VERSION}"

  log "下载 Neovim ${NVIM_VERSION}（${NVIM_ARCH}）..."
  curl -fL --http1.1 --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 15 \
    "$url" -o "$TMP_DIR/$asset"

  [[ -n "$NVIM_SHA256" ]] \
    || die "未提供 Neovim 校验和；覆盖 NVIM_VERSION 时必须同时设置 NVIM_SHA256。"
  printf '%s  %s\n' "$NVIM_SHA256" "$TMP_DIR/$asset" | sha256sum -c -

  rm -rf "$prefix"
  install -d "$prefix"
  tar -xzf "$TMP_DIR/$asset" -C "$prefix" --strip-components=1
  [[ -x "$prefix/bin/nvim" ]] || die "Neovim 压缩包结构不符合预期。"
  ln -sfn "$prefix/bin/nvim" "$LOCAL_BIN/nvim"

  log "Neovim 已安装: $LOCAL_BIN/nvim"
}

CURRENT_NVIM="$(nvim_current_version || true)"
if [[ "$CURRENT_NVIM" == "$NVIM_VERSION" ]]; then
  log "Neovim 已是 ${NVIM_VERSION}，跳过。"
else
  install -d "$LOCAL_BIN" "$LOCAL_OPT"
  if [[ -z "$TMP_DIR" ]]; then
    TMP_DIR="$(mktemp -d)"
  fi
  install_neovim
fi

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
    CC=gcc \
    XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" \
    bash "$NVIM_CONFIG_SRC/scripts/build-latex-parser.sh"
fi

log "版本检查："
"$NVIM_BIN" --version | head -n 1
"$FZF_BIN" --version
rg --version | head -n 1
if command -v fd >/dev/null 2>&1; then
  fd --version
elif [[ -x "$LOCAL_BIN/fd" ]]; then
  "$LOCAL_BIN/fd" --version
else
  warn "fd 命令不可用。"
fi
"$LOCAL_BIN/tree-sitter" --version
TMUX_INSTALLED="$("$LOCAL_BIN/tmux" -V 2>/dev/null | awk '{print $2}')"
[[ "$TMUX_INSTALLED" == "$TMUX_VERSION" ]] \
  || die "tmux 版本是 ${TMUX_INSTALLED:-unknown}，期望 ${TMUX_VERSION}。"
log "tmux ${TMUX_INSTALLED}"
if [[ -x /usr/bin/tmux ]]; then
  warn "系统仍存在 /usr/bin/tmux ($(/usr/bin/tmux -V 2>/dev/null))；dev_env 使用 $LOCAL_BIN/tmux，不自动卸载系统包。"
fi
zsh --version
"$LOCAL_BIN/starship" --version

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
  *":$LOCAL_BIN:"*)
    ;;
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

if command -v nvim >/dev/null 2>&1; then
  NVIM_RESOLVED="$(command -v nvim)"
  if [[ "$NVIM_RESOLVED" != "$NVIM_BIN" ]]; then
    warn "当前 shell 解析到的 nvim 是 ${NVIM_RESOLVED}，而不是 ${NVIM_BIN}。"
    warn "请检查 PATH 顺序，确保 $LOCAL_BIN 在 /usr/bin 前面。"
  fi
fi

if command -v fzf >/dev/null 2>&1; then
  FZF_RESOLVED="$(command -v fzf)"
  if [[ "$FZF_RESOLVED" != "$FZF_BIN" ]]; then
    warn "当前 shell 解析到的 fzf 是 ${FZF_RESOLVED}，而不是 ${FZF_BIN}。"
    warn "请检查 PATH 顺序，确保 $LOCAL_BIN 在 /usr/bin 前面。"
  fi
fi

log "完成。"
log "启动 Neovim: nvim"
log "tmux 配置: ${XDG_CONFIG_HOME}/tmux/tmux.conf"
if [[ "$SKIP_CONFIG" -eq 0 && "$SKIP_SHELL" -eq 0 ]]; then
  log "shell 配置: ~/.zshrc -> $SHELL_CONFIG_SRC/zshrc"
  log "本地覆盖: ~/.zshrc.local（已存在则未改动）"
fi
log "检查 LSP: bash $NVIM_CONFIG_SRC/scripts/check-lsp.sh（或 :checkhealth vim.lsp）"
log "配置源文件: $NVIM_CONFIG_SRC/init.lua"

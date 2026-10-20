#!/usr/bin/env bash
#
# Ubuntu 24.04 开发环境安装脚本
#
# 安装内容：
#   - Neovim 0.12.x（官方 Linux tarball，用户目录安装）
#   - ripgrep（rg）
#   - fd（Ubuntu 包名为 fd-find，脚本会补一个 fd 命令）
#   - fzf（官方 GitHub release，固定版本）
#   - git / curl / ca-certificates
#   - 把 dev_env/nvim 链接到 Neovim 配置目录
#
# 设计原则：
#   - 不使用 Ubuntu 源里的 neovim（24.04 只有 0.9.5，太旧，不支持 vim.pack）
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
ALLOW_ROOT=0
SUDO=""

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
. "$SCRIPT_DIR/versions.env"
NVIM_SHA256="${NVIM_SHA256:-}"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
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
  --skip-config   只安装工具，不链接 Neovim 配置
  --allow-root    允许以 root 运行（仅建议在容器/CI 中使用）
  -h, --help      显示帮助

可通过环境变量覆盖版本:
  NVIM_VERSION=0.12.3
  FZF_VERSION=0.74.5
  NVIM_SHA256=<sha256>    # 覆盖 Neovim 版本时建议同时提供
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
    ;;
  aarch64|arm64)
    FZF_ARCH="arm64"
    NVIM_ARCH="arm64"
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

# 先刷新一次 sudo 凭据，避免后面多次输入密码
if [[ -n "$SUDO" ]]; then
  "$SUDO" -v
fi

# ---------- 系统包 ----------

log "更新 apt 索引..."
run_sudo apt-get update

read -r -a APT_PACKAGE_ARRAY <<< "$APT_PACKAGES"
log "安装系统包：${APT_PACKAGES}..."
run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
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
  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 \
    "$base_url/$asset" -o "$TMP_DIR/$asset"
  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 \
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
  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 \
    "$url" -o "$TMP_DIR/$asset"

  if [[ -n "$NVIM_SHA256" ]]; then
    printf '%s  %s\n' "$NVIM_SHA256" "$TMP_DIR/$asset" | sha256sum -c -
  else
    warn "未提供 Neovim 校验和，跳过压缩包校验。"
  fi

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

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  log "Neovim 配置冒烟测试："
  if ! "$NVIM_BIN" --headless \
    "+lua print('number='..tostring(vim.o.number)..' relativenumber='..tostring(vim.o.relativenumber)..' mouse='..vim.o.mouse)" \
    +qa; then
    warn "Neovim 配置加载失败，请检查 ${NVIM_CONFIG_DST}。"
  fi
fi

case ":$PATH:" in
  *":$LOCAL_BIN:"*)
    ;;
  *)
    warn "当前 PATH 不包含 ${LOCAL_BIN}。"
    warn "请重新登录，或把下面一行加入 ~/.profile / ~/.zshrc："
    warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

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
log "检查 LSP: :checkhealth vim.lsp（当前尚未配置 LSP）"
log "配置源文件: $NVIM_CONFIG_SRC/init.lua"

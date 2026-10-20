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
ALLOW_ROOT=0
SUDO=""

BUNDLE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
. "$BUNDLE_DIR/versions.env"

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
  --skip-config   只安装工具，不链接 Neovim 配置
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
    ;;
  aarch64|arm64)
    FZF_ARCH="arm64"
    NVIM_ARCH="arm64"
    ;;
  *)
    die "不支持的 CPU 架构: $(uname -m)"
    ;;
esac

[[ -f "$BUNDLE_DIR/SHA256SUMS" ]] || die "找不到 $BUNDLE_DIR/SHA256SUMS；请确认整个离线包已拷贝。"
[[ -f "$BUNDLE_DIR/manifest.txt" ]] || die "找不到 manifest.txt；请确认整个离线包已拷贝。"
BUNDLE_ARCH="$(awk -F= '$1 == "arch" { print $2 }' "$BUNDLE_DIR/manifest.txt")"
[[ "$BUNDLE_ARCH" == "$NVIM_ARCH" ]] || die "离线包架构是 ${BUNDLE_ARCH:-unknown}，当前机器是 ${NVIM_ARCH}。"

FZF_ASSET="fzf-${FZF_VERSION}-linux_${FZF_ARCH}.tar.gz"
NVIM_ASSET="nvim-linux-${NVIM_ARCH}.tar.gz"
[[ -f "$BUNDLE_DIR/$FZF_ASSET" ]] || die "缺少 $FZF_ASSET"
[[ -f "$BUNDLE_DIR/$NVIM_ASSET" ]] || die "缺少 $NVIM_ASSET"
[[ -d "$BUNDLE_DIR/debs" ]] || die "缺少 debs/ 目录"
[[ -d "$BUNDLE_DIR/nvim" ]] || die "缺少 nvim/ 配置目录"

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

for pkg in $APT_PACKAGES; do
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

# Ubuntu 的 fd 包提供 fdfind
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  ln -sfn "$(command -v fdfind)" "$LOCAL_BIN/fd"
  log "已创建 fd -> fdfind 链接: $LOCAL_BIN/fd"
fi

# ---------- Neovim 配置 ----------

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

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  log "Neovim 配置冒烟测试："
  if ! "$NVIM_BIN" --headless \
    "+lua print('number='..tostring(vim.o.number)..' relativenumber='..tostring(vim.o.relativenumber)..' mouse='..vim.o.mouse)" \
    +qa; then
    warn "Neovim 配置加载失败。"
  fi
fi

case ":$PATH:" in
  *":$LOCAL_BIN:"*) ;;
  *)
    warn "当前 PATH 不包含 ${LOCAL_BIN}。"
    warn "请重新登录，或把下面一行加入 ~/.profile / ~/.zshrc："
    warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

log "离线安装完成。"
log "启动 Neovim: nvim"
log "配置目录: ${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

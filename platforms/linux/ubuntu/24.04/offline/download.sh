#!/usr/bin/env bash
#
# 下载 Ubuntu 24.04 离线安装包
#
# 运行环境：联网的 Ubuntu 24.04（架构需与目标机器一致）
# 产物：
#   offline/dist/                         可直接拷贝到离线机器
#   offline/dev_env-ubuntu-24.04-*.tar.gz 打包后的离线包
#
# 用法：
#   bash download.sh
#   bash download.sh --output /path/to/bundle
#   sudo bash download.sh --allow-root     # 仅容器/CI
#
set -euo pipefail

ALLOW_ROOT=0
SUDO=""
OUT_DIR=""
MAKE_TAR=1

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=../versions.env
. "$PLATFORM_DIR/versions.env"

REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

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
用法: download.sh [选项]

选项:
  --output DIR    指定输出目录（默认: 本脚本目录下的 dist）
  --no-tar        只生成目录，不额外打 tar.gz（Docker/CI 常用）
  --allow-root    允许以 root 运行（仅建议在容器/CI 中使用）
  -h, --help      显示帮助

环境变量:
  NVIM_VERSION / FZF_VERSION   覆盖版本
  NVIM_SHA256                 覆盖 Neovim 版本时提供
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || die "--output 需要一个目录参数"
      OUT_DIR="$2"
      shift 2
      ;;
    --no-tar)
      MAKE_TAR=0
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
  command -v sudo >/dev/null 2>&1 || die "需要 sudo 来下载 apt 包。"
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

if [[ -z "${NVIM_SHA256:-}" ]]; then
  if [[ "$NVIM_VERSION" == "0.12.3" ]]; then
    case "$NVIM_ARCH" in
      x86_64) NVIM_SHA256="$NVIM_SHA256_X86_64" ;;
      arm64)  NVIM_SHA256="$NVIM_SHA256_ARM64" ;;
    esac
  else
    die "覆盖 NVIM_VERSION 时请通过 NVIM_SHA256 提供校验和。"
  fi
fi

OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/dist}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
DEBS_DIR="$OUT_DIR/debs"
FZF_ASSET="fzf-${FZF_VERSION}-linux_${FZF_ARCH}.tar.gz"
NVIM_ASSET="nvim-linux-${NVIM_ARCH}.tar.gz"
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

log "输出目录: $OUT_DIR"
log "目标架构: $NVIM_ARCH"
log "Neovim: ${NVIM_VERSION}；fzf: $FZF_VERSION"

# ---------- apt 包 ----------

APT_OPTS=(
  -o Acquire::ForceIPv4=true
  -o Acquire::http::Timeout=30
  -o Acquire::https::Timeout=30
)

log "更新 apt 索引..."
run_sudo apt-get "${APT_OPTS[@]}" update

log "下载 apt 包及依赖到 $DEBS_DIR ..."
rm -rf "$DEBS_DIR"
mkdir -p "$DEBS_DIR"
read -r -a APT_PACKAGE_ARRAY <<< "$APT_PACKAGES_OFFLINE"

# 递归收集依赖，并排除当前系统已安装的包。
# 目标机器按干净的 Ubuntu 24.04 处理；这样下载集合不会因为构建机
# 已经装了 curl 而漏掉 curl 的依赖。
mapfile -t ALL_PKGS < <(
  apt-cache depends --recurse --no-recommends --no-suggests \
    --no-conflicts --no-breaks --no-replaces --no-enhances \
    "${APT_PACKAGE_ARRAY[@]}" \
    | awk '/^[a-zA-Z0-9]/ {print $1}' \
    | sort -u
)
mapfile -t INSTALLED_PKGS < <(dpkg-query -W -f='${Package}\n' | sort -u)
mapfile -t MISSING_PKGS < <(
  comm -23 \
    <(printf '%s\n' "${ALL_PKGS[@]}") \
    <(printf '%s\n' "${INSTALLED_PKGS[@]}")
)
mapfile -t DOWNLOAD_PKGS < <(
  printf '%s\n' "${APT_PACKAGE_ARRAY[@]}" "${MISSING_PKGS[@]}" | sort -u
)

(
  cd "$DEBS_DIR"
  apt-get "${APT_OPTS[@]}" download "${DOWNLOAD_PKGS[@]}"
)

# curl/ca-certificates 用于下载 GitHub release；放在 apt 包下载之后，
# 避免构建机上的 curl 依赖影响离线包内容。
log "确认下载与构建工具..."
run_sudo env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" install -y --no-install-recommends \
  ca-certificates curl git gcc libc6-dev unzip nodejs

# ---------- Neovim / fzf ----------

download_verified() {
  local url="$1"
  local dest="$2"
  local expected="$3"
  local actual

  log "下载 $(basename "$dest") ..."
  curl -fL --http1.1 --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 15 "$url" -o "$dest"
  actual="$(sha256sum "$dest" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    die "校验失败: ${dest}（期望 ${expected}，实际 ${actual}）"
  fi
}

log "下载 Neovim $NVIM_VERSION ..."
curl -fL --http1.1 --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 15 \
  "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/${NVIM_ASSET}" \
  -o "$OUT_DIR/$NVIM_ASSET"
printf '%s  %s\n' "$NVIM_SHA256" "$OUT_DIR/$NVIM_ASSET" | sha256sum -c -

log "下载 fzf $FZF_VERSION ..."
curl -fL --http1.1 --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 15 \
  "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/${FZF_ASSET}" \
  -o "$OUT_DIR/$FZF_ASSET"
curl -fL --http1.1 --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 15 \
  "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf_${FZF_VERSION}_checksums.txt" \
  -o "$TMP_DIR/fzf-checksums.txt"
grep -qE "[[:space:]]${FZF_ASSET}$" "$TMP_DIR/fzf-checksums.txt" || die "fzf 校验文件中找不到 $FZF_ASSET"
grep -E "[[:space:]]${FZF_ASSET}$" "$TMP_DIR/fzf-checksums.txt" | (cd "$OUT_DIR" && sha256sum -c -)

download_verified \
  "https://github.com/tree-sitter/tree-sitter/releases/download/v${TREE_SITTER_VERSION}/${TREE_SITTER_ASSET}" \
  "$OUT_DIR/$TREE_SITTER_ASSET" \
  "$TREE_SITTER_SHA256"

download_verified \
  "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/${STARSHIP_ASSET}" \
  "$OUT_DIR/$STARSHIP_ASSET" \
  "$STARSHIP_SHA256"

download_verified \
  "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONT_VERSION}/${NERD_FONT_ASSET}" \
  "$OUT_DIR/$NERD_FONT_ASSET" \
  "$NERD_FONT_SHA256"

# ---------- 配置与离线安装脚本 ----------

log "复制 Neovim/tmux/shell 配置和离线安装脚本..."
rm -rf "$OUT_DIR/nvim" "$OUT_DIR/tmux" "$OUT_DIR/shell" "$OUT_DIR/lib"
cp -a "$REPO_ROOT/nvim" "$OUT_DIR/nvim"
cp -a "$REPO_ROOT/tmux" "$OUT_DIR/tmux"
cp -a "$REPO_ROOT/shell" "$OUT_DIR/shell"
mkdir -p "$OUT_DIR/lib"
cp -a "$REPO_ROOT/platforms/lib/common.sh" "$OUT_DIR/lib/common.sh"
cp -a "$SCRIPT_DIR/install.sh" "$OUT_DIR/install.sh"
cp -a "$PLATFORM_DIR/versions.env" "$OUT_DIR/versions.env"
chmod +x "$OUT_DIR/install.sh"

log "在临时环境安装 Neovim 插件并编译 latex parser ..."
TOOLS_DIR="$TMP_DIR/tools"
mkdir -p "$TOOLS_DIR/nvim" "$TOOLS_DIR/fzf" "$TOOLS_DIR/tree-sitter"
tar -xzf "$OUT_DIR/$NVIM_ASSET" -C "$TOOLS_DIR/nvim" --strip-components=1
tar -xzf "$OUT_DIR/$FZF_ASSET" -C "$TOOLS_DIR/fzf"
unzip -q -o "$OUT_DIR/$TREE_SITTER_ASSET" -d "$TOOLS_DIR/tree-sitter"
PATH="$TOOLS_DIR/nvim/bin:$TOOLS_DIR/fzf:$TOOLS_DIR/tree-sitter:$PATH" \
  NVIM_BIN="$TOOLS_DIR/nvim/bin/nvim" \
  TREE_SITTER_BIN="$TOOLS_DIR/tree-sitter/tree-sitter" \
  CC=gcc \
  bash "$REPO_ROOT/nvim/scripts/stage-plugins.sh" --output "$OUT_DIR"

cat > "$OUT_DIR/manifest.txt" <<EOF
bundle=dev_env-ubuntu-24.04-${NVIM_ARCH}
created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ubuntu=24.04
arch=${NVIM_ARCH}
neovim=${NVIM_VERSION}
fzf=${FZF_VERSION}
tree_sitter=${TREE_SITTER_VERSION}
starship=${STARSHIP_VERSION}
nerd_font=${NERD_FONT_VERSION}
apt_packages=${APT_PACKAGES_OFFLINE}
EOF

# ---------- 校验和与压缩包 ----------

log "生成 SHA256SUMS ..."
(
  cd "$OUT_DIR"
  find . -type f ! -name SHA256SUMS -print0 \
    | sort -z \
    | xargs -0 sha256sum > SHA256SUMS
)

BUNDLE_NAME="dev_env-ubuntu-24.04-${NVIM_ARCH}.tar.gz"
if [[ "$MAKE_TAR" -eq 1 ]]; then
  log "打包 $BUNDLE_NAME ..."
  tar -czf "$SCRIPT_DIR/$BUNDLE_NAME" -C "$OUT_DIR" .
  log "完成。"
  log "离线包目录: $OUT_DIR"
  log "离线包压缩文件: $SCRIPT_DIR/$BUNDLE_NAME"
  du -sh "$OUT_DIR" "$SCRIPT_DIR/$BUNDLE_NAME" 2>/dev/null || true
  log "把压缩文件拷到离线 Ubuntu 24.04，解压后执行: bash install.sh"
else
  log "完成（--no-tar，未生成 tar.gz）。"
  log "离线包目录: $OUT_DIR"
  du -sh "$OUT_DIR" 2>/dev/null || true
  log "把整个目录拷到离线 Ubuntu 24.04，进入目录执行: bash install.sh"
fi

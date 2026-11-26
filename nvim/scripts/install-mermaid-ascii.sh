#!/usr/bin/env bash
# 安装 mermaid-ascii 单文件二进制到 ~/.local/opt，并链接到 ~/.local/bin。
#
# 用法：bash nvim/scripts/install-mermaid-ascii.sh
# 支持：macOS arm64/x86_64、Linux arm64/x86_64。
# 不需要浏览器、Node、ImageMagick 或 Neovim 插件。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
source "${SCRIPT_DIR}/versions.env"

VERSION="${MERMAID_ASCII_VERSION}"
[[ "$VERSION" =~ ^[0-9]+([.][0-9]+)*$ ]] \
  || {
    printf '[mermaid-ascii] 错误：版本号不合法：%s\n' "$VERSION" >&2
    exit 1
  }
BASE="https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/${VERSION}"
LOCAL_OPT="${HOME}/.local/opt"
LOCAL_BIN="${HOME}/.local/bin"
PREFIX="${LOCAL_OPT}/mermaid-ascii-${VERSION}"

log() { printf '[mermaid-ascii] %s\n' "$*"; }
die() {
  printf '[mermaid-ascii] 错误：%s\n' "$*" >&2
  exit 1
}

# 平台安装器会重复调用本脚本；同版本已安装时只修复链接。
if [[ -x "${PREFIX}/mermaid-ascii" ]] \
  && "${PREFIX}/mermaid-ascii" --help >/dev/null 2>&1; then
  mkdir -p "$LOCAL_BIN"
  ln -sfn "${PREFIX}/mermaid-ascii" "${LOCAL_BIN}/mermaid-ascii"
  log "已安装：${LOCAL_BIN}/mermaid-ascii（${VERSION}）"
  exit 0
fi

os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
  Darwin)
    case "$arch" in
      arm64) asset="mermaid-ascii_Darwin_arm64.tar.gz"; sha="${MERMAID_ASCII_SHA256_DARWIN_ARM64}" ;;
      x86_64) asset="mermaid-ascii_Darwin_x86_64.tar.gz"; sha="${MERMAID_ASCII_SHA256_DARWIN_X86_64}" ;;
      *) die "不支持的 macOS 架构：${arch}" ;;
    esac
    ;;
  Linux)
    case "$arch" in
      aarch64|arm64) asset="mermaid-ascii_Linux_arm64.tar.gz"; sha="${MERMAID_ASCII_SHA256_LINUX_ARM64}" ;;
      x86_64|amd64) asset="mermaid-ascii_Linux_x86_64.tar.gz"; sha="${MERMAID_ASCII_SHA256_LINUX_X86_64}" ;;
      *) die "不支持的 Linux 架构：${arch}" ;;
    esac
    ;;
  *) die "不支持的操作系统：${os}（仅 macOS / Linux）" ;;
esac

command -v curl >/dev/null 2>&1 || die "找不到 curl"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "下载 ${asset}（${VERSION}）"
curl -fsSL --retry 3 --connect-timeout 15 -o "${tmp}/${asset}" "${BASE}/${asset}"

log "校验 SHA256"
if command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "${tmp}/${asset}" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "${tmp}/${asset}" | awk '{print $1}')"
else
  die "找不到 shasum 或 sha256sum"
fi
[ "$actual" = "$sha" ] || die "SHA256 不匹配：期望 ${sha}，实际 ${actual}"

log "安装到 ${PREFIX}"
rm -rf "${PREFIX:?}"
mkdir -p "$PREFIX" "$LOCAL_BIN"
tar -xzf "${tmp}/${asset}" -C "$PREFIX"
[ -x "${PREFIX}/mermaid-ascii" ] || die "压缩包里没有可执行的 mermaid-ascii"
chmod +x "${PREFIX}/mermaid-ascii"
ln -sfn "${PREFIX}/mermaid-ascii" "${LOCAL_BIN}/mermaid-ascii"

"${LOCAL_BIN}/mermaid-ascii" --help >/dev/null
log "已安装：${LOCAL_BIN}/mermaid-ascii"
case ":${PATH}:" in
  *":${LOCAL_BIN}:"*) ;;
  *) log "提示：${LOCAL_BIN} 不在 PATH 中，请把它加入 PATH" ;;
esac

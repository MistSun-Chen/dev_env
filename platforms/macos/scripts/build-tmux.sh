#!/usr/bin/env bash
#
# Build a self-contained macOS tmux binary.
#
# The resulting binary statically links libevent and utf8proc and uses the
# system ncurses. It has no /opt/homebrew or build-directory runtime paths,
# so it can be shipped in an offline bundle and run without a compiler.
#
# Usage:
#   bash build-tmux.sh --output DIR
#   bash build-tmux.sh --output DIR --keep
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=../versions.env
. "$PLATFORM_DIR/versions.env"

OUT_DIR=""
WORK_DIR=""
KEEP=0
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}"

log()  { printf '\033[1;32m[build-tmux]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[build-tmux]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[build-tmux]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
用法: build-tmux.sh --output DIR [选项]

选项:
  --output DIR             输出目录（必需；生成 tmux 二进制和 build-info.txt）
  --work DIR               构建目录（默认: mktemp）
  --deployment-target VER  macOS 最低版本（默认: 12.0）
  --keep                   保留构建目录
  -h, --help               显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || die "--output 需要一个目录参数"
      OUT_DIR="$2"
      shift 2
      ;;
    --work)
      [[ $# -ge 2 ]] || die "--work 需要一个目录参数"
      WORK_DIR="$2"
      shift 2
      ;;
    --deployment-target)
      [[ $# -ge 2 ]] || die "--deployment-target 需要一个版本参数"
      DEPLOYMENT_TARGET="$2"
      shift 2
      ;;
    --keep)
      KEEP=1
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
[[ -n "$OUT_DIR" ]] || die "缺少 --output DIR。"
[[ "${EUID}" -ne 0 ]] || die "请不要用 root 运行。"

case "$(uname -m)" in
  arm64|aarch64)
    HOST_ARCH="arm64"
    ;;
  x86_64|amd64)
    HOST_ARCH="x86_64"
    ;;
  *)
    die "不支持的 CPU 架构: $(uname -m)"
    ;;
esac

for tool in cc make curl tar shasum otool file; do
  command -v "$tool" >/dev/null 2>&1 || die "缺少构建工具: $tool"
done

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd -- "$OUT_DIR" && pwd)"
if [[ -z "$WORK_DIR" ]]; then
  WORK_DIR="$(mktemp -d)"
else
  mkdir -p "$WORK_DIR"
  WORK_DIR="$(cd -- "$WORK_DIR" && pwd)"
fi

cleanup() {
  if [[ "$KEEP" -eq 0 && -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

download_verify() {
  local url="$1"
  local dest="$2"
  local expected="$3"
  local actual

  log "下载 $(basename "$dest") ..."
  curl -fL --http1.1 --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 15 "$url" -o "$dest"
  actual="$(shasum -a 256 "$dest" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    die "校验失败: ${dest}（期望 ${expected}，实际 ${actual}）"
  fi
}

SRC_DIR="$WORK_DIR/src"
BUILD_DIR="$WORK_DIR/build"
PREFIX="$BUILD_DIR/prefix"
mkdir -p "$SRC_DIR" "$PREFIX"

download_verify \
  "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz" \
  "$SRC_DIR/tmux.tar.gz" \
  "$TMUX_SHA256"
download_verify \
  "https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}-stable/libevent-${LIBEVENT_VERSION}-stable.tar.gz" \
  "$SRC_DIR/libevent.tar.gz" \
  "$LIBEVENT_SHA256"
download_verify \
  "https://github.com/JuliaStrings/utf8proc/releases/download/v${UTF8PROC_VERSION}/utf8proc-${UTF8PROC_VERSION}.tar.gz" \
  "$SRC_DIR/utf8proc.tar.gz" \
  "$UTF8PROC_SHA256"

tar -xzf "$SRC_DIR/libevent.tar.gz" -C "$SRC_DIR"
tar -xzf "$SRC_DIR/utf8proc.tar.gz" -C "$SRC_DIR"
tar -xzf "$SRC_DIR/tmux.tar.gz" -C "$SRC_DIR"

LIBEVENT_SRC="$SRC_DIR/libevent-${LIBEVENT_VERSION}-stable"
UTF8PROC_SRC="$SRC_DIR/utf8proc-${UTF8PROC_VERSION}"
TMUX_SRC="$SRC_DIR/tmux-${TMUX_VERSION}"
LIBEVENT_PREFIX="$PREFIX/libevent"
UTF8PROC_PREFIX="$PREFIX/utf8proc"
TMUX_PREFIX="$PREFIX/tmux"

log "编译 libevent ${LIBEVENT_VERSION}（static）..."
(
  cd "$LIBEVENT_SRC"
  env CFLAGS="-O2 -mmacosx-version-min=$DEPLOYMENT_TARGET" \
      LDFLAGS="-mmacosx-version-min=$DEPLOYMENT_TARGET" \
      ./configure --prefix="$LIBEVENT_PREFIX" \
        --disable-shared --enable-static \
        --disable-openssl --disable-samples --disable-libevent-regress
  make -j"$(sysctl -n hw.ncpu)"
  make install
)

log "编译 utf8proc ${UTF8PROC_VERSION}（static）..."
(
  cd "$UTF8PROC_SRC"
  make clean >/dev/null 2>&1 || true
  make libutf8proc.a CFLAGS="-O2 -mmacosx-version-min=$DEPLOYMENT_TARGET"
  install -d "$UTF8PROC_PREFIX/lib" "$UTF8PROC_PREFIX/include"
  install -m 644 libutf8proc.a "$UTF8PROC_PREFIX/lib/libutf8proc.a"
  install -m 644 utf8proc.h "$UTF8PROC_PREFIX/include/utf8proc.h"
)

log "编译 tmux ${TMUX_VERSION} ..."
(
  cd "$TMUX_SRC"
  # Force configure to use the direct header/library checks below rather than
  # accidentally picking up Homebrew libraries through pkg-config.
  env PKG_CONFIG=/usr/bin/false \
      CFLAGS="-O2 -mmacosx-version-min=$DEPLOYMENT_TARGET" \
      CPPFLAGS="-I$LIBEVENT_PREFIX/include -I$UTF8PROC_PREFIX/include" \
      LDFLAGS="-L$LIBEVENT_PREFIX/lib -L$UTF8PROC_PREFIX/lib -mmacosx-version-min=$DEPLOYMENT_TARGET" \
      ./configure --prefix="$TMUX_PREFIX" \
        --enable-utf8proc --disable-jemalloc --disable-systemd
  make -j"$(sysctl -n hw.ncpu)"
)

TMUX_BIN="$TMUX_SRC/tmux"
[[ -x "$TMUX_BIN" ]] || die "tmux 构建失败，找不到 $TMUX_BIN"

log "校验 tmux 二进制..."
"$TMUX_BIN" -V | grep -q "tmux ${TMUX_VERSION}" || die "tmux 版本不符合预期。"
file "$TMUX_BIN" | grep -q "$HOST_ARCH" || die "tmux 二进制架构不是 ${HOST_ARCH}。"

if otool -L "$TMUX_BIN" | tail -n +2 | grep -E '/opt/homebrew|/usr/local|@rpath|'"$WORK_DIR"'/'; then
  die "tmux 仍依赖 Homebrew/构建目录；拒绝生成不可移植的离线二进制。"
fi

install -m 755 "$TMUX_BIN" "$OUT_DIR/tmux"
cat > "$OUT_DIR/build-info.txt" <<EOF
tmux=${TMUX_VERSION}
libevent=${LIBEVENT_VERSION}
utf8proc=${UTF8PROC_VERSION}
arch=${HOST_ARCH}
deployment_target=${DEPLOYMENT_TARGET}
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

log "完成: $OUT_DIR/tmux"
otool -L "$OUT_DIR/tmux"

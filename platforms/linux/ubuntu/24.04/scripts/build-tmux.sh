#!/usr/bin/env bash
#
# Build a self-contained Ubuntu 24.04 tmux binary.
#
# libevent and utf8proc are linked statically; ncurses comes from the
# distribution and is available on the offline target. The resulting binary
# has no build-directory or /usr/local runtime paths.
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

log()  { printf '\033[1;32m[build-tmux]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[build-tmux]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[build-tmux]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
用法: build-tmux.sh --output DIR [选项]

选项:
  --output DIR             输出目录（必需；生成 tmux 二进制和 build-info.txt）
  --work DIR               构建目录（默认: mktemp；用户指定的目录不会被删除）
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

[[ "$(uname -s)" == "Linux" ]] || die "此脚本只支持 Linux。"
[[ -n "$OUT_DIR" ]] || die "缺少 --output DIR。"

case "$(uname -m)" in
  x86_64|amd64)
    HOST_ARCH="x86_64"
    ;;
  aarch64|arm64)
    HOST_ARCH="aarch64"
    ;;
  *)
    die "不支持的 CPU 架构: $(uname -m)"
    ;;
esac

for tool in cc make curl tar sha256sum file ldd; do
  command -v "$tool" >/dev/null 2>&1 || die "缺少构建工具: $tool"
done

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd -- "$OUT_DIR" && pwd)"
WORK_DIR_IS_TEMP=0
if [[ -z "$WORK_DIR" ]]; then
  WORK_DIR="$(mktemp -d)"
  WORK_DIR_IS_TEMP=1
else
  mkdir -p "$WORK_DIR"
  WORK_DIR="$(cd -- "$WORK_DIR" && pwd)"
fi

cleanup() {
  # Never delete a user-supplied --work directory.
  if [[ "$KEEP" -eq 0 && "$WORK_DIR_IS_TEMP" -eq 1 && -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf "${WORK_DIR:?}"
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
  actual="$(sha256sum "$dest" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    die "校验失败: ${dest}（期望 ${expected}，实际 ${actual}）"
  fi
}

read -r JOBS < <(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)
[[ "$JOBS" =~ ^[0-9]+$ ]] || JOBS=2

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
  env CFLAGS="-O2 -fPIC" \
      ./configure --prefix="$LIBEVENT_PREFIX" \
        --disable-shared --enable-static \
        --disable-openssl --disable-samples --disable-libevent-regress
  make -j"$JOBS"
  make install
)

log "编译 utf8proc ${UTF8PROC_VERSION}（static）..."
(
  cd "$UTF8PROC_SRC"
  make clean >/dev/null 2>&1 || true
  make libutf8proc.a CFLAGS="-O2 -fPIC"
  install -d "$UTF8PROC_PREFIX/lib" "$UTF8PROC_PREFIX/include"
  install -m 644 libutf8proc.a "$UTF8PROC_PREFIX/lib/libutf8proc.a"
  install -m 644 utf8proc.h "$UTF8PROC_PREFIX/include/utf8proc.h"
)

log "编译 tmux ${TMUX_VERSION} ..."
(
  cd "$TMUX_SRC"
  env PKG_CONFIG=/usr/bin/false \
      CFLAGS="-O2" \
      CPPFLAGS="-I$LIBEVENT_PREFIX/include -I$UTF8PROC_PREFIX/include" \
      LDFLAGS="-L$LIBEVENT_PREFIX/lib -L$UTF8PROC_PREFIX/lib" \
      ./configure --prefix="$TMUX_PREFIX" \
        --enable-utf8proc --disable-jemalloc --disable-systemd
  make -j"$JOBS"
)

TMUX_BIN="$TMUX_SRC/tmux"
[[ -x "$TMUX_BIN" ]] || die "tmux 构建失败，找不到 $TMUX_BIN"

log "校验 tmux 二进制..."
"$TMUX_BIN" -V | grep -q "tmux ${TMUX_VERSION}" || die "tmux 版本不符合预期。"

case "$HOST_ARCH" in
  x86_64)
    file "$TMUX_BIN" | grep -Eq 'x86-64|x86_64' || die "tmux 二进制架构不是 x86_64。"
    ;;
  aarch64)
    file "$TMUX_BIN" | grep -Eq 'aarch64|ARM aarch64' || die "tmux 二进制架构不是 aarch64。"
    ;;
esac

if ldd "$TMUX_BIN" | grep -E "$WORK_DIR|/usr/local|not found"; then
  die "tmux 仍依赖构建目录、/usr/local 或缺失库；拒绝生成不可移植的离线二进制。"
fi
if ldd "$TMUX_BIN" | grep -E 'libevent|libutf8proc'; then
  die "tmux 仍动态依赖 libevent/utf8proc；静态链接失败，拒绝生成离线二进制。"
fi
if command -v readelf >/dev/null 2>&1 \
  && readelf -d "$TMUX_BIN" | grep -E 'RPATH|RUNPATH'; then
  die "tmux 包含 RPATH/RUNPATH；拒绝生成不可移植的离线二进制。"
fi

install -m 755 "$TMUX_BIN" "$OUT_DIR/tmux"
cat > "$OUT_DIR/build-info.txt" <<EOF
tmux=${TMUX_VERSION}
libevent=${LIBEVENT_VERSION}
utf8proc=${UTF8PROC_VERSION}
arch=${HOST_ARCH}
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

log "完成: $OUT_DIR/tmux"
ldd "$OUT_DIR/tmux" || true
if [[ "$WORK_DIR_IS_TEMP" -eq 0 || "$KEEP" -eq 1 ]]; then
  log "保留构建目录: $WORK_DIR"
fi

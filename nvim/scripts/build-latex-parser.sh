#!/usr/bin/env bash
#
# 编译并安装 markview 公式渲染所需的 latex Tree-sitter parser。
#
# 依赖：
#   tree-sitter CLI >= 0.26.1
#   C 编译器（macOS: cc；Ubuntu: gcc + libc6-dev）
#
# 安装位置：
#   ${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/parser/latex.so
#
# 用法：
#   bash nvim/scripts/build-latex-parser.sh
#   TREE_SITTER_BIN=/path/to/tree-sitter CC=cc bash nvim/scripts/build-latex-parser.sh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
. "$SCRIPT_DIR/versions.env"

NVIM_BIN="${NVIM_BIN:-nvim}"
TREE_SITTER_BIN="${TREE_SITTER_BIN:-tree-sitter}"
CC="${CC:-cc}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
PARSER_DIR="$DATA_HOME/nvim/site/parser"
TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

die() { printf '\033[1;31m[latex-parser]\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;32m[latex-parser]\033[0m %s\n' "$*"; }

command -v "$NVIM_BIN" >/dev/null 2>&1 || die "找不到 Neovim：$NVIM_BIN"
command -v "$TREE_SITTER_BIN" >/dev/null 2>&1 || die "找不到 tree-sitter CLI；请先运行平台安装脚本"
command -v "$CC" >/dev/null 2>&1 || die "找不到 C 编译器：$CC"
command -v node >/dev/null 2>&1 || die "找不到 Node.js；tree-sitter generate 需要它（只用于构建 parser）"

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

download() {
  local url="$1"
  local dest="$2"
  curl -fL --http1.1 --retry 3 --retry-delay 2 --connect-timeout 15 "$url" -o "$dest"
}

SRC_TAR="$TMP_DIR/tree-sitter-latex.tar.gz"
log "下载 tree-sitter-latex ${TREE_SITTER_LATEX_VERSION} ..."
download "$TREE_SITTER_LATEX_URL" "$SRC_TAR"
ACTUAL="$(sha256_file "$SRC_TAR")"
[[ "$ACTUAL" == "$TREE_SITTER_LATEX_SHA256" ]] || die "tree-sitter-latex 校验失败（期望 ${TREE_SITTER_LATEX_SHA256}，实际 ${ACTUAL}）"

tar -xzf "$SRC_TAR" -C "$TMP_DIR"
SRC_DIR="$TMP_DIR/tree-sitter-latex-${TREE_SITTER_LATEX_VERSION}"
[[ -f "$SRC_DIR/grammar.js" ]] || die "tree-sitter-latex 压缩包结构不符合预期"

log "生成 parser.c ..."
(
  cd "$SRC_DIR"
  "$TREE_SITTER_BIN" generate
)

[[ -f "$SRC_DIR/src/parser.c" ]] || die "tree-sitter generate 没有生成 src/parser.c"

# scanner.c 需要 tree_sitter/parser.h；部分 grammar 仓库不提交该头文件。
if [[ ! -f "$SRC_DIR/src/tree_sitter/parser.h" ]]; then
  log "补齐 tree_sitter/parser.h ..."
  TS_TAR="$TMP_DIR/tree-sitter-src.tar.gz"
  download "$TREE_SITTER_SOURCE_URL" "$TS_TAR"
  ACTUAL="$(sha256_file "$TS_TAR")"
  [[ "$ACTUAL" == "$TREE_SITTER_SOURCE_SHA256" ]] || die "tree-sitter 源码校验失败"
  mkdir -p "$SRC_DIR/src/tree_sitter"
  tar -xOzf "$TS_TAR" "tree-sitter-${TREE_SITTER_VERSION}/lib/src/parser.h" > "$SRC_DIR/src/tree_sitter/parser.h"
fi

log "编译 latex.so ..."
(
  cd "$SRC_DIR"
  if ! "$CC" -O2 -fPIC -shared src/parser.c src/scanner.c -I src -o "$TMP_DIR/latex.so"; then
    log "cc -shared 失败，尝试 macOS -dynamiclib ..."
    "$CC" -O2 -fPIC -dynamiclib src/parser.c src/scanner.c -I src -o "$TMP_DIR/latex.so"
  fi
)

install -d "$PARSER_DIR"
install -m 0644 "$TMP_DIR/latex.so" "$PARSER_DIR/latex.so"
log "已安装：$PARSER_DIR/latex.so"

log "验证 parser 加载 ..."
XDG_DATA_HOME="$DATA_HOME" "$NVIM_BIN" --headless -u NONE \
  --cmd "set rtp^=$DATA_HOME/nvim/site" \
  "+lua assert(vim.treesitter.language.add('latex'))" +qa

log "latex parser 构建完成。"

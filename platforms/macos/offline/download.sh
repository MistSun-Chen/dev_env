#!/usr/bin/env bash
#
# 下载 macOS 离线安装包
#
# 运行环境：联网 macOS；架构需与目标机器一致
# 产物：
#   offline/dist/
#   offline/dev_env-macos-<arch>.tar.gz
#
set -euo pipefail

OUT_DIR=""
MAKE_TAR=1

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=../versions.env
. "$PLATFORM_DIR/versions.env"

REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

log()  { printf '\033[1;32m[offline]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[offline]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[offline]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
用法: download.sh [选项]

选项:
  --output DIR    指定输出目录（默认: 本脚本目录下的 dist）
  --no-tar        只生成目录，不额外打 tar.gz
  -h, --help      显示帮助
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
[[ "${EUID}" -ne 0 ]] || die "请不要用 root 运行。"

case "$(uname -m)" in
  arm64)
    ARCH="arm64"
    NVIM_ASSET="nvim-macos-arm64.tar.gz"
    FZF_ASSET="fzf-${FZF_VERSION}-darwin_arm64.tar.gz"
    RG_ASSET="ripgrep-${RG_VERSION}-aarch64-apple-darwin.tar.gz"
    FD_ASSET="fd-v${FD_VERSION}-aarch64-apple-darwin.tar.gz"
    TREE_SITTER_ASSET="tree-sitter-cli-macos-arm64.zip"
    STARSHIP_ASSET="starship-aarch64-apple-darwin.tar.gz"
    NVIM_SHA="$NVIM_SHA256_ARM64"
    FZF_SHA="$FZF_SHA256_ARM64"
    RG_SHA="$RG_SHA256_ARM64"
    FD_SHA="$FD_SHA256_ARM64"
    TREE_SITTER_SHA="$TREE_SITTER_SHA256_ARM64"
    STARSHIP_SHA="$STARSHIP_SHA256_ARM64"
    ;;
  x86_64)
    ARCH="x86_64"
    NVIM_ASSET="nvim-macos-x86_64.tar.gz"
    FZF_ASSET="fzf-${FZF_VERSION}-darwin_amd64.tar.gz"
    RG_ASSET="ripgrep-${RG_VERSION}-x86_64-apple-darwin.tar.gz"
    FD_ASSET="fd-v${FD_VERSION}-x86_64-apple-darwin.tar.gz"
    TREE_SITTER_ASSET="tree-sitter-cli-macos-x64.zip"
    STARSHIP_ASSET="starship-x86_64-apple-darwin.tar.gz"
    NVIM_SHA="$NVIM_SHA256_X86_64"
    FZF_SHA="$FZF_SHA256_X86_64"
    RG_SHA="$RG_SHA256_X86_64"
    FD_SHA="$FD_SHA256_X86_64"
    TREE_SITTER_SHA="$TREE_SITTER_SHA256_X86_64"
    STARSHIP_SHA="$STARSHIP_SHA256_X86_64"
    ;;
  *)
    die "不支持的 CPU 架构: $(uname -m)"
    ;;
esac

OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/dist}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
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

log "输出目录: $OUT_DIR"
log "目标架构: $ARCH"

download_verify \
  "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/${NVIM_ASSET}" \
  "$OUT_DIR/$NVIM_ASSET" \
  "$NVIM_SHA"

download_verify \
  "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/${FZF_ASSET}" \
  "$OUT_DIR/$FZF_ASSET" \
  "$FZF_SHA"

download_verify \
  "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/${RG_ASSET}" \
  "$OUT_DIR/$RG_ASSET" \
  "$RG_SHA"

download_verify \
  "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/${FD_ASSET}" \
  "$OUT_DIR/$FD_ASSET" \
  "$FD_SHA"

download_verify \
  "https://github.com/tree-sitter/tree-sitter/releases/download/v${TREE_SITTER_VERSION}/${TREE_SITTER_ASSET}" \
  "$OUT_DIR/$TREE_SITTER_ASSET" \
  "$TREE_SITTER_SHA"

download_verify \
  "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/${STARSHIP_ASSET}" \
  "$OUT_DIR/$STARSHIP_ASSET" \
  "$STARSHIP_SHA"

download_verify \
  "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONT_VERSION}/${NERD_FONT_ASSET}" \
  "$OUT_DIR/$NERD_FONT_ASSET" \
  "$NERD_FONT_SHA256"

log "构建自包含 tmux ${TMUX_VERSION} ..."
TMUX_BUILD_DIR="$TMP_DIR/tmux-build"
bash "$PLATFORM_DIR/scripts/build-tmux.sh" --output "$TMUX_BUILD_DIR"
install -m 755 "$TMUX_BUILD_DIR/tmux" "$OUT_DIR/tmux-bin"
cp -a "$TMUX_BUILD_DIR/build-info.txt" "$OUT_DIR/tmux-build-info.txt"

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

command -v node >/dev/null 2>&1 || die "需要 Node.js 来运行 tree-sitter generate；请先安装 Node（仅构建 parser 时需要）"

log "在临时环境安装 Neovim 插件并编译 latex parser ..."
TOOLS_DIR="$TMP_DIR/tools"
mkdir -p "$TOOLS_DIR/nvim" "$TOOLS_DIR/fzf" "$TOOLS_DIR/tree-sitter"
tar -xzf "$OUT_DIR/$NVIM_ASSET" -C "$TOOLS_DIR/nvim" --strip-components=1
tar -xzf "$OUT_DIR/$FZF_ASSET" -C "$TOOLS_DIR/fzf"
unzip -q -o "$OUT_DIR/$TREE_SITTER_ASSET" -d "$TOOLS_DIR/tree-sitter"
PATH="$TOOLS_DIR/nvim/bin:$TOOLS_DIR/fzf:$TOOLS_DIR/tree-sitter:$PATH" \
  NVIM_BIN="$TOOLS_DIR/nvim/bin/nvim" \
  TREE_SITTER_BIN="$TOOLS_DIR/tree-sitter/tree-sitter" \
  CC=cc \
  bash "$REPO_ROOT/nvim/scripts/stage-plugins.sh" --output "$OUT_DIR"

cat > "$OUT_DIR/manifest.txt" <<EOF
bundle=dev_env-macos-${ARCH}
created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
macos=$(sw_vers -productVersion 2>/dev/null || echo unknown)
arch=${ARCH}
neovim=${NVIM_VERSION}
fzf=${FZF_VERSION}
ripgrep=${RG_VERSION}
fd=${FD_VERSION}
tree_sitter=${TREE_SITTER_VERSION}
tmux=${TMUX_VERSION}
starship=${STARSHIP_VERSION}
nerd_font=${NERD_FONT_VERSION}
EOF

log "生成 SHA256SUMS ..."
(
  cd "$OUT_DIR"
  find . -type f ! -name SHA256SUMS -exec shasum -a 256 {} + | sort > SHA256SUMS
)

BUNDLE_NAME="dev_env-macos-${ARCH}.tar.gz"
if [[ "$MAKE_TAR" -eq 1 ]]; then
  log "打包 $BUNDLE_NAME ..."
  tar -czf "$SCRIPT_DIR/$BUNDLE_NAME" -C "$OUT_DIR" .
  log "完成。"
  log "离线包目录: $OUT_DIR"
  log "离线包压缩文件: $SCRIPT_DIR/$BUNDLE_NAME"
  du -sh "$OUT_DIR" "$SCRIPT_DIR/$BUNDLE_NAME" 2>/dev/null || true
  log "把压缩文件拷到离线 macOS，解压后执行: bash install.sh"
else
  log "完成（--no-tar，未生成 tar.gz）。"
  log "离线包目录: $OUT_DIR"
  du -sh "$OUT_DIR" 2>/dev/null || true
  log "把整个目录拷到离线 macOS，进入目录执行: bash install.sh"
fi

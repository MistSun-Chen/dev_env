#!/usr/bin/env bash
#
# Network-free safety test for the macOS offline installer.
#
# Uses a synthetic bundle with fake tool binaries to exercise the installer's
# data-safety paths without downloading 100+ MB or touching the real HOME:
#   - configs are copied out of the temporary bundle before linking
#   - --skip-config does not delete existing plugins or latex.so
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

[[ "$(uname -s)" == "Darwin" ]] || {
  echo "[offline-safety-smoke] 非 macOS，跳过"
  exit 0
}
command -v zip >/dev/null 2>&1 || {
  echo "[offline-safety-smoke] 缺少 zip，跳过"
  exit 0
}

case "$(uname -m)" in
  arm64)
    ARCH="arm64"
    NVIM_ASSET="nvim-macos-arm64.tar.gz"
    FZF_ASSET="fzf-0.74.5-darwin_arm64.tar.gz"
    RG_ASSET="ripgrep-15.2.0-aarch64-apple-darwin.tar.gz"
    FD_ASSET="fd-v10.5.0-aarch64-apple-darwin.tar.gz"
    TS_ASSET="tree-sitter-cli-macos-arm64.zip"
    STARSHIP_ASSET="starship-aarch64-apple-darwin.tar.gz"
    ;;
  x86_64)
    ARCH="x86_64"
    NVIM_ASSET="nvim-macos-x86_64.tar.gz"
    FZF_ASSET="fzf-0.74.5-darwin_amd64.tar.gz"
    RG_ASSET="ripgrep-15.2.0-x86_64-apple-darwin.tar.gz"
    FD_ASSET="fd-v10.5.0-x86_64-apple-darwin.tar.gz"
    TS_ASSET="tree-sitter-cli-macos-x64.zip"
    STARSHIP_ASSET="starship-x86_64-apple-darwin.tar.gz"
    ;;
  *)
    echo "[offline-safety-smoke] 不支持的架构: $(uname -m)，跳过"
    exit 0
    ;;
esac

log() { printf '[offline-safety-smoke] %s\n' "$*"; }
die() { printf '[offline-safety-smoke] %s\n' "$*" >&2; exit 1; }

BUNDLE="$(mktemp -d)"
TMP_HOME="$(mktemp -d)"
TMP_XDG="$(mktemp -d)"
TMP_ASSETS="$(mktemp -d)"
INSTALL_LOG="$(mktemp)"
SKIP_LOG="$(mktemp)"
cleanup() { rm -rf "$BUNDLE" "$TMP_HOME" "$TMP_XDG" "$TMP_ASSETS"; rm -f "$INSTALL_LOG" "$SKIP_LOG"; }
trap cleanup EXIT

cp -a "$REPO_ROOT/nvim" "$REPO_ROOT/tmux" "$REPO_ROOT/shell" "$BUNDLE/"
mkdir -p "$BUNDLE/lib" "$BUNDLE/nvim-parser"
cp -a "$REPO_ROOT/platforms/lib/common.sh" "$BUNDLE/lib/"
cp -a "$REPO_ROOT/platforms/macos/offline/install.sh" "$BUNDLE/install.sh"
cp -a "$REPO_ROOT/platforms/macos/versions.env" "$BUNDLE/versions.env"
chmod +x "$BUNDLE/install.sh"

for name in lazy.nvim which-key.nvim gitsigns.nvim fzf-lua markview.nvim \
  grug-far.nvim neo-tree.nvim nui.nvim plenary.nvim lazydev.nvim \
  nvim-lspconfig catppuccin; do
  mkdir -p "$BUNDLE/nvim-plugins/$name"
done
printf 'fake parser\n' > "$BUNDLE/nvim-parser/latex.so"

fake_bin() {
  local path="$1" text="$2"
  printf '#!/bin/sh\n%s\n' "$text" > "$path"
  chmod +x "$path"
}

mkdir -p "$TMP_ASSETS/nvim/bin"
fake_bin "$TMP_ASSETS/nvim/bin/nvim" 'case "$1" in --version) echo "NVIM v0.12.3";; *) exit 0;; esac'
tar -czf "$BUNDLE/$NVIM_ASSET" -C "$TMP_ASSETS" nvim

fake_bin "$TMP_ASSETS/fzf" 'echo "0.74.5"'
tar -czf "$BUNDLE/$FZF_ASSET" -C "$TMP_ASSETS" fzf

mkdir -p "$TMP_ASSETS/ripgrep" "$TMP_ASSETS/fd"
fake_bin "$TMP_ASSETS/ripgrep/rg" 'echo "ripgrep 15.2.0"'
fake_bin "$TMP_ASSETS/fd/fd" 'echo "fd 10.5.0"'
tar -czf "$BUNDLE/$RG_ASSET" -C "$TMP_ASSETS" ripgrep
tar -czf "$BUNDLE/$FD_ASSET" -C "$TMP_ASSETS" fd

fake_bin "$TMP_ASSETS/tree-sitter" 'echo "tree-sitter 0.27.1"'
( cd "$TMP_ASSETS" && zip -q "$BUNDLE/$TS_ASSET" tree-sitter )

fake_bin "$TMP_ASSETS/starship" 'echo "starship 1.27.0"'
tar -czf "$BUNDLE/$STARSHIP_ASSET" -C "$TMP_ASSETS" starship

fake_bin "$BUNDLE/tmux-bin" 'echo "tmux 3.8"'
printf 'tmux=3.8\n' > "$BUNDLE/tmux-build-info.txt"
mkdir -p "$TMP_ASSETS/fonts"
for f in MesloLGSNerdFont-Regular.ttf MesloLGSNerdFont-Bold.ttf \
  MesloLGSNerdFont-Italic.ttf MesloLGSNerdFont-BoldItalic.ttf; do
  printf 'font\n' > "$TMP_ASSETS/fonts/$f"
done
tar -cJf "$BUNDLE/Meslo.tar.xz" -C "$TMP_ASSETS/fonts" .

cat > "$BUNDLE/manifest.txt" <<EOF
bundle=dev_env-macos-${ARCH}
created=test
arch=${ARCH}
neovim=0.12.3
fzf=0.74.5
ripgrep=15.2.0
fd=10.5.0
tree_sitter=0.27.1
tmux=3.8
starship=1.27.0
nerd_font=3.5.1
EOF

( cd "$BUNDLE" && find . -type f ! -name SHA256SUMS -exec shasum -a 256 {} + | sort > SHA256SUMS )

log "完整安装（合成包，临时 HOME）..."
PATH="$TMP_HOME/.local/bin:$PATH" HOME="$TMP_HOME" XDG_CONFIG_HOME="$TMP_XDG" \
  bash "$BUNDLE/install.sh" >"$INSTALL_LOG" 2>&1

[[ -d "$TMP_HOME/.local/share/dev_env/config" ]] \
  || { cat "$INSTALL_LOG" >&2; die "稳定配置目录未创建"; }
CONFIG_ROOT="$(cd "$TMP_HOME/.local/share/dev_env/config" && pwd -P)"
[[ -f "$CONFIG_ROOT/nvim/init.lua" ]] || { cat "$INSTALL_LOG" >&2; die "缺少稳定 nvim 配置"; }
[[ -f "$CONFIG_ROOT/shell/zshrc" ]] || { cat "$INSTALL_LOG" >&2; die "缺少稳定 shell 配置"; }
case "$(readlink "$TMP_HOME/.zshrc")" in "$CONFIG_ROOT"/*) ;; *) die ".zshrc 未指向稳定副本" ;; esac
case "$(readlink "$TMP_XDG/nvim")" in "$CONFIG_ROOT"/*) ;; *) die "nvim 配置未指向稳定副本" ;; esac
case "$(readlink "$TMP_XDG/tmux/tmux.conf")" in "$CONFIG_ROOT"/*) ;; *) die "tmux 配置未指向稳定副本" ;; esac

log "--skip-config 保留已有插件和 parser ..."
mkdir -p "$TMP_HOME/.local/share/nvim/lazy/fzf-lua"
printf 'keep\n' > "$TMP_HOME/.local/share/nvim/lazy/fzf-lua/.keep"
printf 'keep\n' > "$TMP_HOME/.local/share/nvim/site/parser/latex.so"
PATH="$TMP_HOME/.local/bin:$PATH" HOME="$TMP_HOME" XDG_CONFIG_HOME="$TMP_XDG" \
  bash "$BUNDLE/install.sh" --skip-config >"$SKIP_LOG" 2>&1
[[ -f "$TMP_HOME/.local/share/nvim/lazy/fzf-lua/.keep" ]] \
  || { cat "$SKIP_LOG" >&2; die "--skip-config 删除了已有插件"; }
grep -q keep "$TMP_HOME/.local/share/nvim/site/parser/latex.so" \
  || { cat "$SKIP_LOG" >&2; die "--skip-config 覆盖了已有 parser"; }

log "通过"

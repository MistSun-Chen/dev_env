#!/usr/bin/env bash
#
# 在临时 XDG 目录中测试 lazy.nvim 插件安装、latex parser 和 Mermaid 渲染。
# 不会修改真实 ~/.config/nvim。
#
# 用法：
#   bash tests/nvim-plugins-smoke.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_CONFIG="$(mktemp -d)"
TMP_DATA="$(mktemp -d)"
SAMPLE="$TMP_CONFIG/sample.md"

cleanup() { rm -rf "$TMP_CONFIG" "$TMP_DATA"; }
trap cleanup EXIT

# 复制配置而不是链接，避免测试改写仓库里的 lazy-lock.json。
mkdir -p "$TMP_CONFIG"
cp -a "$REPO_ROOT/nvim" "$TMP_CONFIG/nvim"

cat > "$SAMPLE" <<'EOF'
# Smoke Test

## Details

Inline: $E = mc^2$

```mermaid
graph LR
A --> B
```
EOF

echo "[test] 安装 lazy.nvim 与插件到临时目录"
XDG_CONFIG_HOME="$TMP_CONFIG" XDG_DATA_HOME="$TMP_DATA" \
  bash "$REPO_ROOT/nvim/scripts/install-plugins.sh"
XDG_CONFIG_HOME="$TMP_CONFIG" XDG_DATA_HOME="$TMP_DATA" \
  bash "$REPO_ROOT/nvim/scripts/install-plugins.sh" --check

echo "[test] 编译 latex parser 到临时目录"
XDG_DATA_HOME="$TMP_DATA" \
  bash "$REPO_ROOT/nvim/scripts/build-latex-parser.sh"

echo "[test] 检查 lockfile、lazy.nvim 和插件目录"
[[ -f "$TMP_CONFIG/nvim/lazy-lock.json" ]]
for name in lazy.nvim fzf-lua markview.nvim; do
  [[ -d "$TMP_DATA/nvim/lazy/$name" ]]
done

EXPECTED_LAZY_COMMIT="$(sed -n "s/^local lazy_commit = '\([0-9a-f]*\)'.*/\1/p" "$REPO_ROOT/nvim/lua/config/lazy.lua")"
ACTUAL_LAZY_COMMIT="$(git -C "$TMP_DATA/nvim/lazy/lazy.nvim" rev-parse HEAD)"
[[ "$ACTUAL_LAZY_COMMIT" == "$EXPECTED_LAZY_COMMIT" ]]

echo "[test] 检查插件、配色与 TOC"
XDG_CONFIG_HOME="$TMP_CONFIG" XDG_DATA_HOME="$TMP_DATA" \
  nvim --headless "$SAMPLE" \
  "+set filetype=markdown" \
  "+lua assert(pcall(require,'lazy')); assert(pcall(require,'fzf-lua')); assert(pcall(require,'markview')); assert(vim.treesitter.language.add('latex')); assert(vim.g.colors_name == 'catppuccin-mocha'); local colors=vim.fn.getcompletion('', 'color'); for _,n in ipairs({'catppuccin-mocha','catppuccin-macchiato','catppuccin-frappe','catppuccin-latte'}) do assert(vim.tbl_contains(colors,n), n) end; local toc=require('config.markdown_toc'); assert(#toc.get_headings(0) >= 2); print('toc/colors: ok')" \
  +qa

echo "[test] 检查 Mermaid extmark"
XDG_CONFIG_HOME="$TMP_CONFIG" XDG_DATA_HOME="$TMP_DATA" \
  nvim --headless "$SAMPLE" \
  "+set filetype=markdown" \
  "+MermaidRender" \
  "+sleep 1" \
  "+lua local ns=vim.api.nvim_get_namespaces()['dev_env_mermaid']; assert(ns, 'mermaid namespace missing'); assert(#vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) > 0, 'mermaid virt_lines missing')" \
  +qa

echo "[test] 通过"

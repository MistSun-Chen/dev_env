#!/usr/bin/env bash
#
# 在临时 XDG 目录中测试 lazy.nvim 插件安装、latex parser 和基础配置。
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
for name in lazy.nvim which-key.nvim fzf-lua markview.nvim grug-far.nvim neo-tree.nvim nui.nvim plenary.nvim lazydev.nvim nvim-lspconfig; do
  [[ -d "$TMP_DATA/nvim/lazy/$name" ]]
done

EXPECTED_LAZY_COMMIT="$(sed -n "s/^local lazy_commit = '\([0-9a-f]*\)'.*/\1/p" "$REPO_ROOT/nvim/lua/config/lazy.lua")"
ACTUAL_LAZY_COMMIT="$(git -C "$TMP_DATA/nvim/lazy/lazy.nvim" rev-parse HEAD)"
[[ "$ACTUAL_LAZY_COMMIT" == "$EXPECTED_LAZY_COMMIT" ]]

echo "[test] 检查插件、配色与 TOC"
XDG_CONFIG_HOME="$TMP_CONFIG" XDG_DATA_HOME="$TMP_DATA" \
  nvim --headless "$SAMPLE" \
  "+set filetype=markdown" \
  "+lua assert(pcall(require,'lazy')); assert(pcall(require,'which-key')); assert(pcall(require,'fzf-lua')); assert(pcall(require,'markview')); assert(pcall(require,'grug-far')); assert(pcall(require,'neo-tree')); assert(pcall(require,'lazydev')); assert(vim.lsp.config ~= nil); assert(vim.fn.maparg('<leader>ld','n') ~= ''); assert(vim.fn.maparg('<leader>ls','n') ~= ''); assert(vim.o.completeopt:find('noselect',1,true) ~= nil); assert(vim.treesitter.language.add('latex')); assert(vim.g.colors_name == 'catppuccin-mocha'); local colors=vim.fn.getcompletion('', 'color'); for _,n in ipairs({'catppuccin-mocha','catppuccin-macchiato','catppuccin-frappe','catppuccin-latte'}) do assert(vim.tbl_contains(colors,n), n) end; local toc=require('config.markdown_toc'); assert(#toc.get_headings(0) >= 2); assert(vim.o.showtabline == 2); assert(vim.o.tabline:find('config.tabline') ~= nil); assert(require('config.tabline').render() ~= nil); assert(vim.fn.exists('*DevEnvTablineClick') == 1); assert(vim.fn.maparg('<leader>fc','n') ~= ''); assert(vim.fn.maparg('<leader>bs','n') ~= ''); assert(vim.fn.maparg('<leader>sr','n') ~= ''); assert(vim.fn.maparg('<leader>et','n') ~= ''); assert(vim.fn.maparg('<leader>er','n') == ''); local et=vim.fn.maparg('<leader>et','n',false,true); assert(et.rhs:find('Neotree toggle',1,true) ~= nil); vim.cmd('Neotree toggle'); local ntc=require('neo-tree').config; assert(ntc.filesystem.window.fuzzy_finder_mappings['<c-j>'] == 'move_cursor_down'); assert(ntc.filesystem.window.fuzzy_finder_mappings['<c-k>'] == 'move_cursor_up'); assert(ntc.window.auto_expand_width == true); local tree=false; for _,w in ipairs(vim.api.nvim_list_wins()) do if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'neo-tree' then tree=true end end; assert(tree, 'neo-tree window missing'); print('toc/colors/tabline/neo-tree: ok'); vim.wait(1000)" \
  +qa!

echo "[test] 通过"

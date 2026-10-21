#!/usr/bin/env bash
#
# 在临时 XDG 目录中测试插件安装、latex parser 和 Mermaid 渲染。
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

cat > "$SAMPLE" <<'EOF'
# Smoke Test

Inline: $E = mc^2$

```mermaid
graph LR
A --> B
```
EOF

echo "[test] 安装插件到临时目录"
XDG_CONFIG_HOME="$TMP_CONFIG" XDG_DATA_HOME="$TMP_DATA" \
  bash "$REPO_ROOT/nvim/scripts/install-plugins.sh"
XDG_CONFIG_HOME="$TMP_CONFIG" XDG_DATA_HOME="$TMP_DATA" \
  bash "$REPO_ROOT/nvim/scripts/install-plugins.sh" --check

echo "[test] 编译 latex parser 到临时目录"
XDG_DATA_HOME="$TMP_DATA" \
  bash "$REPO_ROOT/nvim/scripts/build-latex-parser.sh"

echo "[test] 检查插件与 parser"
XDG_CONFIG_HOME="$TMP_CONFIG" XDG_DATA_HOME="$TMP_DATA" \
  nvim --headless \
  "+lua assert(pcall(require,'fzf-lua')); assert(pcall(require,'markview')); assert(vim.treesitter.language.add('latex'))" \
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

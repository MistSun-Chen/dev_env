#!/usr/bin/env bash
# Mermaid ASCII 混合预览的轻量冒烟测试。
#
# 需要 nvim 和 mermaid-ascii；缺少 mermaid-ascii 时跳过（退出 0），
# 便于没有安装该二进制的 CI/开发机运行其余测试。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NVIM_BIN="${NVIM_BIN:-nvim}"

if ! command -v "$NVIM_BIN" >/dev/null 2>&1; then
  echo "[mermaid-ascii-smoke] 跳过：找不到 nvim"
  exit 0
fi
if ! command -v mermaid-ascii >/dev/null 2>&1; then
  echo "[mermaid-ascii-smoke] 跳过：找不到 mermaid-ascii（可运行 nvim/scripts/install-mermaid-ascii.sh）"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/init.lua" <<LUA
vim.opt.rtp:prepend('$ROOT/nvim')
require('config.mermaid_ascii')
LUA

cat >"$TMP/test.md" <<'MD'
# Mermaid ASCII smoke

```mermaid
flowchart LR
  A --> B
```

```mermaid
flowchart LR
  A[Ghostty] --> B[SSH]
  B --> C[Linux]
  C --> D[Neovim]
  D --> E[Markdown]
  D --> F[mermaid-ascii]
  F --> G[extmark]
  E --> H[wrap]
  G --> I[hint]
  I --> J[split]
```
MD

out="$(
  "$NVIM_BIN" --headless --cmd 'set columns=60' -u "$TMP/init.lua" "$TMP/test.md" \
    "+set filetype=markdown" "+sleep 1" \
    "+lua local ns=vim.api.nvim_get_namespaces()['dev_env_mermaid_ascii']; local m=vim.api.nvim_buf_get_extmarks(0,ns,0,-1,{details=true}); local hint=0; for _,e in ipairs(m) do for _,line in ipairs(e[4].virt_lines or {}) do local s=''; for _,ch in ipairs(line) do s=s..ch[1] end; if s:find('图过宽',1,true) then hint=hint+1 end end end; print('marks='..#m); print('hint='..hint); print('fm='..vim.wo.foldmethod); print('fl='..vim.wo.foldlevel)" \
    +qa 2>&1
)"

echo "$out" | grep -q '^marks=2$' || {
  echo "[mermaid-ascii-smoke] 失败：预期 marks=2" >&2
  echo "$out" >&2
  exit 1
}
echo "$out" | grep -q '^hint=1$' || {
  echo "[mermaid-ascii-smoke] 失败：预期只有宽图有 hint=1" >&2
  echo "$out" >&2
  exit 1
}
echo "$out" | grep -q '^fm=expr$' || {
  echo "[mermaid-ascii-smoke] 失败：预期 foldmethod=expr" >&2
  echo "$out" >&2
  exit 1
}
echo "$out" | grep -q '^fl=0$' || {
  echo "[mermaid-ascii-smoke] 失败：预期 foldlevel=0" >&2
  echo "$out" >&2
  exit 1
}

echo "[mermaid-ascii-smoke] 通过"

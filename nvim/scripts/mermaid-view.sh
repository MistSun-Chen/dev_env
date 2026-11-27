#!/usr/bin/env bash
# 从 Markdown 中提取第 N 个 Mermaid 代码块并渲染成 ASCII。
#
# 用法：mermaid-view.sh [-n N] FILE
#   -n N   1-based Mermaid 块序号，默认 1
#
# 只依赖 mermaid-ascii；不启动浏览器，不使用 Kitty/图片协议。
# 宽图可在 shell 里加宽终端，或在 Neovim 里用 <leader>mb 横向滚动。
set -euo pipefail

n=1
file=""
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--number) n="${2:?缺少块序号}"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    -*) echo "未知选项：$1" >&2; exit 2 ;;
    *) file="$1"; shift ;;
  esac
done

[ -n "$file" ] && [ -f "$file" ] || {
  echo "用法：mermaid-view.sh [-n N] FILE" >&2
  exit 2
}

command -v mermaid-ascii >/dev/null 2>&1 || {
  echo "找不到 mermaid-ascii；先运行 bash nvim/scripts/install-mermaid-ascii.sh" >&2
  exit 1
}

block="$(awk -v want="$n" '
  /^[[:space:]]*```mermaid[[:space:]]*$/ { inb=1; count++; next }
  inb && /^[[:space:]]*```[[:space:]]*$/ { inb=0; next }
  inb && count==want { print }
' "$file")"

[ -n "$block" ] || {
  echo "找不到第 ${n} 个 mermaid 块：${file}" >&2
  exit 1
}

printf '%s\n' "$block" | mermaid-ascii -f - --max-width "${COLS:-120}"

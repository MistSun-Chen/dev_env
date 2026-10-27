#!/usr/bin/env bash
#
# 检查 dev_env 使用的 language server 和 C/C++ 工具链。
# 只读，不安装任何东西。
#
# 用法：
#   bash nvim/scripts/check-lsp.sh
#   bash nvim/scripts/check-lsp.sh --strict   # 有缺失时返回 1
#
set -euo pipefail

STRICT=0

usage() {
  cat <<'EOF'
用法: check-lsp.sh [--strict]

  --strict   有必需项缺失时返回 1
  -h, --help 显示帮助
EOF
}

case "${1:-}" in
  --strict)
    STRICT=1
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

case "$(uname -s)" in
  Darwin)
    node_hint="brew install node（或使用 nvm）"
    clangd_hint="xcode-select --install"
    c_hint="xcode-select --install"
    cpp_hint="xcode-select --install"
    ;;
  Linux)
    node_hint="sudo apt install nodejs npm（Ubuntu）或使用 nvm"
    clangd_hint="sudo apt install clangd"
    c_hint="sudo apt install gcc libc6-dev（或 build-essential）"
    cpp_hint="sudo apt install g++ libc6-dev（或 build-essential）"
    ;;
  *)
    node_hint="安装 Node.js（>= 18）"
    clangd_hint="安装 clangd"
    c_hint="安装 C 编译器"
    cpp_hint="安装 C++ 编译器"
    ;;
esac

missing=0

check_cmd() {
  local cmd="$1" label="$2" hint="$3" optional="${4:-0}"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '[ok]      %-24s %s\n' "$label" "$(command -v "$cmd")"
  elif [[ "$optional" == "1" ]]; then
    printf '[optional] %-23s %s\n' "$label" "$hint"
  else
    printf '[missing] %-24s %s\n' "$label" "$hint"
    missing=1
  fi
}

check_any() {
  local label="$1" commands="$2" hint="$3" cmd found=""
  for cmd in $commands; do
    if command -v "$cmd" >/dev/null 2>&1; then
      found="$cmd"
      break
    fi
  done

  if [[ -n "$found" ]]; then
    printf '[ok]      %-24s %s\n' "$label" "$(command -v "$found")"
  else
    printf '[missing] %-24s %s\n' "$label" "$hint"
    missing=1
  fi
}

check_cmd lua-language-server "lua_ls" "按 nvim/README.md 的 LSP 一节安装"
check_cmd pyright-langserver "pyright" "先安装 Node.js，再按 nvim/README.md 安装 pyright"
check_cmd bash-language-server "bashls" "先安装 Node.js，再按 nvim/README.md 安装 bash-language-server"
check_cmd clangd "clangd" "$clangd_hint"

printf '\n'
check_cmd node "Node.js" "$node_hint"
check_cmd npm "npm" "$node_hint"
check_any "C compiler" "cc gcc clang" "$c_hint"
check_any "C++ compiler" "c++ g++ clang++" "$cpp_hint"

if [[ "$(uname -s)" == "Linux" ]]; then
  if [[ -r /usr/include/stdio.h ]]; then
    printf '[ok]      %-24s %s\n' "C headers" "/usr/include/stdio.h"
  else
    printf '[missing] %-24s %s\n' "C headers" "sudo apt install libc6-dev（或 build-essential）"
    missing=1
  fi

  if [[ -d /usr/include/c++ ]]; then
    printf '[ok]      %-24s %s\n' "C++ headers" "/usr/include/c++"
  else
    printf '[missing] %-24s %s\n' "C++ headers" "sudo apt install g++（或 build-essential）"
    missing=1
  fi
fi

printf '\n'
check_cmd shellcheck "shellcheck (optional)" "可选；Bash 的额外诊断需要它" 1

if [[ "$missing" -ne 0 ]]; then
  printf '\n有缺失项。缺少 server 不会阻止 Neovim 启动，只会影响对应语言的 LSP。\n'
  if [[ "$STRICT" -eq 1 ]]; then
    exit 1
  fi
else
  printf '\n所有 LSP 依赖已就绪。\n'
fi

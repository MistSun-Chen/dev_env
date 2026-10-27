#!/usr/bin/env bash
# LSP 练习：Bash 主文件。
#
# 试试：
# - K 悬停
# - gd 跳转到函数或变量定义
# - grr 查看引用
# - grn 重命名（例如 user_name -> name）
# - <leader>ls 查看当前文件符号
#
# BashLS 首次打开需要几秒索引；如果 K/gd 暂时没结果，稍等再试。

set -euo pipefail

greet() {
  local person="$1"
  printf 'Hello, %s\n' "$person"
}

user_name="Ada"
greet "$user_name"

# 输入 greet 或 user_name 时试试补全。

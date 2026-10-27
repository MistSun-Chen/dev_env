#!/usr/bin/env bash
# LSP 练习：故意制造 shellcheck 诊断。
#
# 打开后按 [d / ]d 跳转；<leader>ld 查看列表。

name="Ada"
echo $name

# 故意问题：cd 失败时没有处理
cd /tmp

# 故意问题：变量赋值后没有使用
unused="never_used"

# 故意问题：变量没有定义
echo "$undefined_name"

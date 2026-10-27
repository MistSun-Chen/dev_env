# LSP 练习样例

这组样例用于快速熟悉 Neovim 的 LSP 操作。每个语言目录里都有：

- `main.*`：干净、可运行的代码，用来练跳转、引用、重命名、补全；
- `diagnostics.*`：故意包含错误的代码，用来练诊断跳转和 code action。

先确认本机 server 是否齐全：

```sh
cd /path/to/dev_env
bash nvim/scripts/check-lsp.sh
```

## 打开样例

```sh
cd /path/to/dev_env

nvim samples/lsp/python/app.py
nvim samples/lsp/bash/main.sh
nvim samples/lsp/c/main.c
nvim samples/lsp/cpp/main.cpp
```

也可以直接在文件树里打开 `samples/lsp/`。C/C++ 目录下的 `compile_flags.txt` 已经写好，clangd 会据此解析代码。

## 通用操作

| 键位 | 操作 |
|---|---|
| `K` | 悬停：类型、签名、文档 |
| `gd` | 跳到定义 |
| `grr` | 查看引用 |
| `grn` | 重命名；先看 `grr` 的范围，再决定是否跨文件改 |
| `gri` | 查看实现；主要对 C++ 虚函数等有意义 |
| `gra` | code action；光标要在诊断或可操作的位置上 |
| `[d` / `]d` | 上一个 / 下一个诊断 |
| `<leader>ld` | 当前文件诊断列表 |
| `<leader>ls` | 当前文件符号列表 |
| `<C-x><C-o>` | 手动触发 LSP 补全 |
| `<C-n>` / `<C-p>` | 补全候选上下移动 |
| `<C-y>` | 接受补全 |

## Python

文件：

- `python/app.py`：主文件
- `python/models.py`：`User` 和 `display_name`
- `python/diagnostics.py`：类型错误
- `python/pyrightconfig.json`：让同目录的 `from models import ...` 可解析

练习：

1. 在 `app.py` 里把光标放到 `User` 上按 `gd`，跳到 `models.py`。
2. 在 `display_name` 上按 `grr`，看引用；再按 `grn` 改成别的名字，观察跨文件修改。
3. 输入 `user.` 看成员补全；输入 `display_name(` 看签名。
4. 打开 `diagnostics.py`，按 `]d` 跳到诊断；把光标放到错误上按 `gra`。

## Bash

文件：

- `bash/main.sh`：主文件，函数和变量都在同一个文件里
- `bash/diagnostics.sh`：shellcheck 诊断

练习：

1. 打开后稍等几秒让 BashLS 建索引；把光标放到 `greet` 上按 `K`、`gd`、`grr`。
2. 在 `user_name` 上按 `grn` 改名，观察引用是否一起变化。
3. 输入变量名时看补全。
4. 打开 `diagnostics.sh`，按 `]d` 查看 shellcheck 的 `cd`、未使用变量、未定义变量诊断。

BashLS 也支持重命名和引用，但能力比 clangd/Pyright 少；对 `source` 进来的跨文件符号解析也有限，所以这里把函数放在同一个文件里。某些位置没有结果属于正常现象。

## C

文件：

- `c/main.c`：主文件
- `c/math_utils.c` / `c/math_utils.h`：`add`、`point_sum`、`Point`
- `c/diagnostics.c`：类型和参数错误

练习：

1. 在 `Point` 上按 `gd`、`grr`，再按 `grn` 改名；如果只看到头文件里的结果，先打开 `math_utils.c` / `main.c` 或等 clangd 完成索引。
2. 在 `add` 上按 `K` 看签名，按 `gd` 跳定义，按 `grr` 看调用点。
3. 输入 `p.` 看结构体成员补全。
4. 打开 `diagnostics.c`，用 `]d` 看错误；在错误位置按 `gra` 看 clangd 的修复建议。

## C++

文件：

- `cpp/main.cpp`：主文件
- `cpp/widget.cpp` / `cpp/widget.hpp`：`Widget`、`Button`
- `cpp/diagnostics.cpp`：类型错误

练习：

1. 在 `Widget` / `Button` 上按 `gd`、`grr`、`grn`；跨文件结果需要先打开 `widget.cpp` / `main.cpp`，或等 clangd 建完索引。
2. 在 `draw` 上按 `gri`，查看基类和派生类的实现关系；按 `grr` 看所有调用/实现。
3. 输入 `widget.` 看成员补全；在 `Widget(` 处看构造函数签名。
4. 打开 `diagnostics.cpp`，用 `]d` 和 `gra` 查看 clangd 诊断与修复建议。

## 说明

- `diagnostics.*` 里的错误是故意的；修掉后诊断会消失。在当前环境下预期至少有：Python 2 条、Bash 3 条、C 2 条、C++ 2 条诊断；server 版本不同可能略有差异。
- `gra` 是否有内容取决于 server 和光标位置，提示 `No code actions available` 不一定是配置错误。
- C/C++ 的解析依赖 `compile_flags.txt`；如果项目变大，建议改用 CMake 的 `compile_commands.json`。clangd 的跨文件 `grr` / `grn` 依赖已打开或已索引的文件；只打开头文件时可能只看得到头文件内部的结果。
- Bash 的额外诊断依赖 `shellcheck`；没有它时补全、悬停仍可用。
- Python 样例只用标准库；真实项目有第三方依赖时，可用 `:LspPyrightSetPythonPath` 指定虚拟环境。

# 使用与安装

本文是 `dev_env` 的使用说明。README 只保留入口和概览。

## 1. 仓库提供什么

每个平台安装以下工具：

- Neovim 0.12.x
- ripgrep（`rg`）
- fd
- fzf
- git（`lazy.nvim` 引导和插件安装需要）
- `tree-sitter` CLI（编译公式 parser）
- Node.js（仅构建公式 parser 时需要，不是 Neovim 运行时依赖）

并把仓库根目录的 `nvim/` 链接或复制到该平台的 Neovim 配置目录。

Neovim 插件由 `nvim/scripts/install-plugins.sh` 安装；公式所需 `latex` parser 由 `nvim/scripts/build-latex-parser.sh` 编译。

当前支持：

| 平台 | 联网安装 | 离线安装 |
|---|---|---|
| Ubuntu 24.04 | 支持 | 支持 |
| macOS（Apple Silicon / Intel） | 支持 | 支持 |
| Windows | 待实现 | 待实现 |

## 2. 联网安装

### 2.1 Ubuntu 24.04

```sh
git clone git@github.com:MistSun-Chen/dev_env.git
cd dev_env
bash platforms/linux/ubuntu/24.04/install.sh
exec "$SHELL" -l
```

只安装工具、不接管 Neovim 配置（也不会安装插件/公式 parser）：

```sh
bash platforms/linux/ubuntu/24.04/install.sh --skip-config
```

容器/CI 中允许 root：

```sh
bash platforms/linux/ubuntu/24.04/install.sh --allow-root --skip-config
```

### 2.2 macOS

要求已安装 [Homebrew](https://brew.sh/)。

```sh
git clone git@github.com:MistSun-Chen/dev_env.git
cd dev_env
bash platforms/macos/install.sh
exec "$SHELL" -l
```

只安装工具、不接管 Neovim 配置（也不会安装插件/公式 parser）：

```sh
bash platforms/macos/install.sh --skip-config
```

### 2.3 安装脚本做了什么

Ubuntu：

- apt 安装 `ca-certificates`、`curl`、`git`、`ripgrep`、`fd-find`、`gcc`、`libc6-dev`、`unzip`、`nodejs`；不安装 `npm`、`g++`、`clangd` 或 language server；
- 补 `~/.local/bin/fd -> fdfind`；
- 从官方 release 安装 Neovim 0.12.3、fzf 0.74.5、tree-sitter 0.27.1，并校验 SHA256；
- 备份并链接 `~/.config/nvim -> <repo>/nvim`；
- 调用 `nvim/scripts/install-plugins.sh` 安装插件，调用 `build-latex-parser.sh` 编译公式 parser。

macOS：

- 缺失时用 Homebrew 安装 `ripgrep`、`fd`、`git`、`node`；
- 从官方 release 安装 Neovim 0.12.3、fzf 0.74.5、tree-sitter 0.27.1，并校验 SHA256；
- 备份并链接 `~/.config/nvim -> <repo>/nvim`；
- 调用 `nvim/scripts/install-plugins.sh` 安装插件，调用 `build-latex-parser.sh` 编译公式 parser。

已有配置会备份为：

```text
~/.config/nvim.bak.YYYYMMDD-HHMMSS
```

## 3. Neovim 插件与 Markdown 预览

### 3.1 插件安装

插件清单在 `nvim/lua/config/plugins.lua`。lazy.nvim 自身由 `nvim/lua/config/lazy.lua` 引导并固定 commit；其他插件的实际 revision 由 `nvim/lazy-lock.json` 固定。单独安装：

```sh
bash nvim/scripts/install-plugins.sh
```

只检查，不访问网络（离线安装/CI 用）：

```sh
bash nvim/scripts/install-plugins.sh --check
```

脚本会检查 `nvim`、`git`、`fzf`，执行 `nvim --headless "+Lazy! install"`，并验证：

- `lazy.nvim`
- `which-key.nvim`
- `gitsigns.nvim`
- `fzf-lua`
- `markview.nvim`
- `grug-far.nvim`
- `neo-tree.nvim` 及其依赖 `nui.nvim`、`plenary.nvim`
- `nvim-lspconfig`、`lazydev.nvim`
- `catppuccin` 配色插件

插件安装位置：

```text
~/.local/share/nvim/lazy/lazy.nvim
~/.local/share/nvim/lazy/which-key.nvim
~/.local/share/nvim/lazy/gitsigns.nvim
~/.local/share/nvim/lazy/fzf-lua
~/.local/share/nvim/lazy/markview.nvim
~/.local/share/nvim/lazy/grug-far.nvim
~/.local/share/nvim/lazy/neo-tree.nvim
~/.local/share/nvim/lazy/nui.nvim
~/.local/share/nvim/lazy/plenary.nvim
~/.local/share/nvim/lazy/nvim-lspconfig
~/.local/share/nvim/lazy/lazydev.nvim
~/.local/share/nvim/lazy/catppuccin
```

`lazy-lock.json` 位于配置目录，软链接模式下就是仓库的 `nvim/lazy-lock.json`，需要提交到 git。lazy.nvim 自身固定到 `nvim/lua/config/lazy.lua` 中的 commit，升级时修改该常量并删除旧插件目录后重新启动。

按 `<leader>` 后停顿约 250ms，which-key 会弹出当前可用的分组和键位说明；继续按 `f`、`b`、`g`、`l`、`s` 等前缀可以逐级查看。忘记某个快捷键时，先按 `<leader>` 比翻文档更快。

不以 `<leader>` 开头的键位：按 `g`、`]`、`[` 后停顿查看前缀下的按键；按 `<leader>?` 查看当前 buffer 的全部键位，包括 LSP 和 gitsigns 的 buffer-local 键位。

打开 Git 仓库中的文件后，gitsigns 会在行号左侧标记新增、修改和删除。常用操作：`]c` / `[c` 跳 hunk，`<leader>gp` 预览，`<leader>gs` 暂存当前 hunk，`<leader>gr` 丢弃，`<leader>gb` 查看 blame，`<leader>gd` 打开 diff。visual 选中多行后按 `<leader>gs` / `<leader>gr` 可只处理选区。

### 3.2 公式 parser

Neovim 0.12 不自带 `latex` Tree-sitter parser。markview 渲染公式前需要：

```sh
bash nvim/scripts/build-latex-parser.sh
```

依赖：

- `tree-sitter` CLI 0.27.1
- C 编译器（macOS `cc`，Ubuntu `gcc`）
- Node.js（只用于 `tree-sitter generate`，不是 Neovim 运行时依赖）

parser 安装到：

```text
${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/parser/latex.so
```

### 3.3 搜索与替换

| 键位/命令 | 功能 |
|---|---|
| `<leader>fg` | 全局搜索；可输入 `query -- *.lua '!vendor/*'` 限定/排除文件 |
| `<leader>fc` | 当前 buffer 搜索 |
| `<leader>fw` | 搜索光标下单词 |
| `<leader>fv` | visual 模式搜索选中文本 |
| `<leader>fs` | 按路径 + glob 搜索，`!` 开头排除 |
| `<leader>sr` | 搜索并替换（grug-far）；visual 模式限制在选区内 |
| `<leader>sR` | 当前文件搜索并替换 |

grug-far 内部：`<Tab>` 切换输入框，`<Space>r` 执行 Replace，`<Space>c` 关闭，`<Space>i` 预览；Paths 是搜索路径，Files Filter 是文件 glob，Flags 是额外 rg 参数。`<Esc>` 只退出插入模式，不关闭 grug-far。

完整键位速查见 [`nvim/keymaps.md`](../nvim/keymaps.md)。

### 3.4 文件树

| 键位/命令 | 功能 |
|---|---|
| `<leader>et` | 打开/关闭文件树（explorer toggle），打开时定位当前文件 |

文件树使用 neo-tree.nvim，默认在左侧显示文件系统；支持 Git 状态、诊断，外部改动会通过 libuv 自动刷新。切换 buffer 时文件树会跟随当前文件。

- `/`：neo-tree 的递归模糊过滤（不是 fzf）；`<C-j>` / `<C-k>`（或 `<C-n>` / `<C-p>` / 方向键）移动，`<Enter>` 打开。大项目里慢的话可以用 `f`，输入完按 Enter 才过滤。
- 宽度默认 32；路径层级变深时会自动加宽，只增不减，不会自动缩回。
- 文件树窗口内用 `?` 查看完整键位，`q` 关闭。

### 3.5 Buffer 与 tabline

| 键位/命令 | 功能 |
|---|---|
| `<leader>bs` | 按 buffer 名称/路径过滤并切换（不搜内容） |
| `<leader>bn` / `<leader>bp` | 下一个 / 上一个 buffer |
| `<leader>bd` | 关闭当前 buffer |

顶部 tabline 显示已打开文件，当前 buffer 高亮，修改过的文件显示 `+`；左键点击标签可切换。

### 3.6 LSP

当前启用 Lua（`lua_ls`）、Python（`pyright`）、Bash（`bashls`）、C/C++（`clangd`）。插件由 lazy.nvim 安装，language server 需要手动安装；平台脚本和离线包暂不包含 server（macOS 的 `clangd` 通常由 Xcode Command Line Tools 提供）。

| 语言 | server | 可执行文件 |
|---|---|---|
| Lua | `lua_ls` | `lua-language-server` |
| Python | `pyright` | `pyright-langserver` |
| Bash | `bashls` | `bash-language-server` |
| C / C++ | `clangd` | `clangd` |

检查本机 server 和 C/C++ 工具链：

```sh
bash nvim/scripts/check-lsp.sh
```

手动安装 `lua-language-server`（Apple Silicon macOS 示例）：

```sh
mkdir -p ~/.local/opt/lua-language-server-3.19.2 ~/.local/bin
curl -L -o /tmp/lua-language-server.tar.gz \
  https://github.com/LuaLS/lua-language-server/releases/download/3.19.2/lua-language-server-3.19.2-darwin-arm64.tar.gz
tar -xzf /tmp/lua-language-server.tar.gz -C ~/.local/opt/lua-language-server-3.19.2
rm -f ~/.local/bin/lua-language-server
cat > ~/.local/bin/lua-language-server <<'EOF'
#!/bin/sh
exec "$HOME/.local/opt/lua-language-server-3.19.2/bin/lua-language-server" "$@"
EOF
chmod +x ~/.local/bin/lua-language-server
lua-language-server --version
```

Linux / Intel Mac 换成对应平台的压缩包；确保 `~/.local/bin` 在 `PATH` 中。

> 不要直接建符号链接：LuaLS 的 bootstrap 二进制按自身路径查找 `main.lua`，符号链接会去 `~/.local/bin/main.lua` 找而失败；用上面的绝对路径 wrapper。

Python 和 Bash 的 server 需要 Node.js（>= 18）和 npm；安装到 `~/.local/opt`，不使用 `npm -g`。Ubuntu 在线安装脚本只装 `nodejs`，如果 `npm` 不存在，先执行 `sudo apt install npm`：

```sh
mkdir -p ~/.local/opt/pyright-1.1.414 ~/.local/opt/bash-language-server-5.8.1 ~/.local/bin
npm install --prefix ~/.local/opt/pyright-1.1.414 --no-fund --no-audit pyright@1.1.414
npm install --prefix ~/.local/opt/bash-language-server-5.8.1 --no-fund --no-audit bash-language-server@5.8.1

cat > ~/.local/bin/pyright-langserver <<'EOF'
#!/bin/sh
exec "$HOME/.local/opt/pyright-1.1.414/node_modules/.bin/pyright-langserver" "$@"
EOF
cat > ~/.local/bin/bash-language-server <<'EOF'
#!/bin/sh
exec "$HOME/.local/opt/bash-language-server-5.8.1/node_modules/.bin/bash-language-server" "$@"
EOF
chmod +x ~/.local/bin/pyright-langserver ~/.local/bin/bash-language-server
```

Pyright 会按 `pyrightconfig.json`、`pyproject.toml` 等识别项目；虚拟环境可用 `:LspPyrightSetPythonPath /path/to/venv/bin/python` 指定。Bash 的 shellcheck 诊断需要本机安装 `shellcheck`（macOS `brew install shellcheck`，Ubuntu `sudo apt install shellcheck`）；没有它时补全和悬停仍然可用。

C/C++ 使用 `clangd`。macOS 安装 Xcode Command Line Tools 后通常已有 `/usr/bin/clangd`；Linux 可用 `sudo apt install clangd`，或安装 LLVM。

Ubuntu 24.04 的注意点：

- 在线安装脚本会装 `gcc`、`libc6-dev`，但不装 `clangd`、`g++` 和 C++ 标准库头文件。C 语言补 `sudo apt install clangd`；C++ 再补 `sudo apt install g++`，或直接 `sudo apt install build-essential`。
- 最小系统/离线安装可能连 C 编译器都没有。此时 clangd 可能能启动，但找不到 `<stdio.h>` 等头文件；补装 `sudo apt install clangd gcc g++ libc6-dev` 或 `build-essential`。
- 纯离线机器无法 `apt install`：要么在离线包里预装 clangd 和编译器，要么暂时不用 C/C++ LSP。
- 运行 `bash nvim/scripts/check-lsp.sh` 查看缺少的 server、编译器和头文件。

为了让 clangd 正确解析项目，建议在项目根目录提供 `compile_flags.txt`，或用 CMake 生成 `compile_commands.json`：

```sh
cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
ln -sf build/compile_commands.json compile_commands.json
```

没有编译数据库时仍可用基础补全和跳转，但系统头文件、宏和第三方库的解析可能不完整。clangd 额外提供 `:LspClangdSwitchSourceHeader`（源文件/头文件切换）和 `:LspClangdShowSymbolInfo`（查看符号信息）。

| 键位 | 功能 |
|---|---|
| `gd` | 跳转定义 |
| `K` | 悬停文档 |
| `grn` | 重命名 |
| `grr` | 查看引用 |
| `gri` | 查看实现 |
| `gra` | code action |
| `grt` | 类型定义 |
| `grx` | 执行 code lens（server 支持时） |
| `gO` | 当前文件符号（quickfix） |
| `<C-s>` | 插入模式签名帮助 |
| `[d` / `]d` | 上一个/下一个诊断 |
| `<leader>ld` | 当前文件诊断列表 |
| `<leader>ls` | 当前文件符号列表 |

助记：`g` = go，`r` = LSP 默认映射固定前缀，第三个字母是动作首字母；`grr` = `g` + `r` + **r**eferences，`gO` 的 `O` = **O**utline。`grr` 打开 quickfix；引用列表操作、自动修复和补全排序等细节见 [`nvim/keymaps.md`](../nvim/keymaps.md)。

Lua、Python、Bash、C/C++ 共用同一套键位。补全由 Neovim 原生 `vim.lsp.completion` 提供：`<C-n>` / `<C-p>` 选择，`<C-y>` 接受，`<C-x><C-o>` 手动触发；补全顺序由 server 决定，Neovim 不按选择频率学习。诊断默认行内显示；自动修复用 `gra` 选择 code action，目前没有保存时自动修复。

LuaLS 首次打开项目需要索引，索引完成前 `K` 可能暂时没有结果；`grn` 只对可重命名的符号生效，`gra` 只在当前位置有 code action 时才有内容，这两类提示不一定是配置错误。`grn` 对局部变量只改当前作用域，对模块字段/导出函数可能跨文件修改 LSP 引用；建议先用 `grr` 看引用范围。

`gra` 示例：写 `local x = missing_name`，等出现未定义全局诊断后，把光标放到 `missing_name` 上按 `gra`，会出现 `Mark missing_name as defined global`、`Disable diagnostics on this line` 等选项。

### 3.7 终端

`<leader>tt` 打开/隐藏底部 12 行终端，使用 Neovim 原生 `:terminal`，不需要额外插件。

- 第一次打开：在底部创建终端并进入插入模式；
- 终端插入模式：按 `<C-\><C-n>` 回到 normal；
- 终端 normal 模式：按 `<leader>tt` 或 `q` 隐藏；
- 隐藏后 shell 进程继续运行，再按 `<leader>tt` 回到同一个终端；
- 要结束 shell，在终端里输入 `exit`。

终端 buffer 不会出现在 tabline，也不会替换当前编辑文件。配置在 `nvim/lua/config/terminal.lua`。

### 3.8 Markdown 预览

打开 Markdown 文件后：

| 键位/命令 | 功能 |
|---|---|
| `<leader>mt` | Markdown 标题目录选择器 |
| `<leader>mp` / `:Markview Toggle` | Markdown 预览开关（所有已附加 buffer） |
| `:Markview toggle` | 只开关当前 buffer 的预览 |
| `<leader>ms` / `:Markview splitToggle` | 分屏预览 |
| `<leader>tc` / `:FzfLua colorschemes` | 切换 Catppuccin 变体 |

默认配色是 `catppuccin-mocha`；配色切换只在当前 Neovim 会话生效。

能力与限制：

- 标题、表格、代码块、引用、链接在 buffer 内渲染；
- `$...$` / `$$...$$` 由 markview 转成 Unicode 近似公式；
- `mermaid` 代码块按普通代码块显示，不做渲染；
- Markdown 本地图片按链接文本显示，不显示图片像素；
- 公式不是 TeX 排版，复杂公式可能不理想。

## 4. 离线安装

离线包不提交到仓库；在联网机器上生成，再拷到离线机器。

### 4.1 Ubuntu 24.04

在联网 Ubuntu 24.04 上：

```sh
cd platforms/linux/ubuntu/24.04/offline
bash download.sh
```

产物：

```text
offline/dist/
offline/dev_env-ubuntu-24.04-<arch>.tar.gz
```

把压缩包拷到离线 Ubuntu 24.04：

```sh
tar -xzf dev_env-ubuntu-24.04-<arch>.tar.gz
cd dev_env-ubuntu-24.04-<arch>
bash install.sh
```

说明：

- 离线包包含 apt deb、Neovim、fzf、tree-sitter、Neovim 插件、预编译 `latex.so`、Neovim 配置和 `SHA256SUMS`；
- 安装使用 `dpkg -i` + `dpkg --configure -a`，不访问网络；
- 下载端和目标端必须同为 Ubuntu 24.04、同一架构（`x86_64` / `arm64`）；
- `download.sh` 会递归收集依赖，并排除构建机已安装的包；目标按干净的 Ubuntu 24.04 处理。

只生成目录、不打包：

```sh
bash download.sh --no-tar --output /tmp/dev_env-offline
```

### 4.2 macOS

在联网 Mac 上：

```sh
cd platforms/macos/offline
bash download.sh
```

产物：

```text
offline/dist/
offline/dev_env-macos-<arch>.tar.gz
```

把压缩包拷到离线 Mac：

```sh
tar -xzf dev_env-macos-<arch>.tar.gz
cd dev_env-macos-<arch>
bash install.sh
```

说明：

- 离线包包含 Neovim、fzf、ripgrep、fd、tree-sitter、Neovim 插件、预编译 `latex.so`、Neovim 配置和 `SHA256SUMS`；
- 不包含 Homebrew 和 git；macOS 通常已有 Xcode Command Line Tools 提供的 `git`；
- Apple Silicon 和 Intel 的包不能混用；
- 安装到 `~/.local/opt/`，命令链接到 `~/.local/bin/`。

## 5. 验证

安装完成后：

```sh
nvim --version | head -1
rg --version | head -1
fd --version
fzf --version
git --version
```

预期：

- `nvim` 为 `v0.12.3`
- `fzf` 为 `0.74.5`
- `rg`、`fd`、`git` 正常输出版本

验证配置：

```sh
nvim --headless "+lua print(vim.o.number, vim.o.relativenumber, vim.o.ignorecase, vim.o.smartcase, vim.o.mouse, vim.o.shortmess:find('I') ~= nil)" +qa
```

期望：

```text
true true true true a true
```

验证插件与公式 parser：

```sh
nvim --headless "+lua assert(pcall(require,'lazy')); assert(pcall(require,'fzf-lua')); assert(pcall(require,'markview')); assert(pcall(require,'grug-far')); assert(pcall(require,'neo-tree')); assert(vim.treesitter.language.add('latex')); assert(vim.fn.maparg('<leader>et','n') ~= ''); assert(vim.fn.maparg('<leader>er','n') == ''); assert(vim.lsp.config ~= nil); assert(vim.fn.maparg('<leader>ld','n') ~= ''); assert(vim.fn.maparg('<leader>ls','n') ~= '')" +qa
```

交互检查：

```vim
:set number? relativenumber? ignorecase? smartcase? mouse? shortmess?
```

- normal / insert 模式按方向键，应出现 `Use h/l/k/j` 提示；
- `Q` 保留 Neovim 默认行为，没有被禁用。

## 6. PATH

`nvim`、`fzf`、`fd`（macOS 离线包还有 `rg`）会链接到 `~/.local/bin`。如果命令找不到：

```sh
echo "$PATH"
command -v nvim
command -v fzf
```

确保 `~/.local/bin` 在 `/usr/bin` 前面。重新登录通常会让 Ubuntu 的 `~/.profile` 生效；自定义 shell 可在 `~/.zshrc` 加入：

```sh
export PATH="$HOME/.local/bin:$PATH"
```

macOS 如果已有 `/usr/local/bin/nvim`，它可能优先于 `~/.local/bin` 被解析；安装脚本会打印实际 `nvim` 版本。

## 7. 修改版本

各平台的版本和校验和在：

- Ubuntu：`platforms/linux/ubuntu/24.04/versions.env`
- macOS：`platforms/macos/versions.env`
- 公式 parser：`nvim/scripts/versions.env`

修改 `NVIM_VERSION` / `FZF_VERSION` / `RG_VERSION` / `FD_VERSION` / `TREE_SITTER_VERSION` 时，必须同步更新对应的 SHA256，否则下载会校验失败。修改 tree-sitter-latex 版本时，同步更新 `nvim/scripts/versions.env` 中的 URL/commit/SHA256，并重新生成离线包。

也可以在运行时覆盖：

```sh
NVIM_VERSION=0.12.3 NVIM_SHA256=<sha256> \
  bash platforms/linux/ubuntu/24.04/install.sh
```

## 8. 回滚

恢复配置：

```sh
rm ~/.config/nvim
mv ~/.config/nvim.bak.YYYYMMDD-HHMMSS ~/.config/nvim
```

删除用户目录安装：

```sh
rm -rf ~/.local/opt/nvim-0.12.3 ~/.local/opt/fzf-0.74.5
rm -rf ~/.local/opt/tree-sitter-0.27.1
rm -f ~/.local/bin/nvim ~/.local/bin/fzf ~/.local/bin/tree-sitter

# 插件和公式 parser
rm -rf ~/.local/share/nvim/lazy
rm -f ~/.local/share/nvim/site/parser/latex.so
rm -f ~/.config/nvim/lazy-lock.json
```

macOS 离线包还会安装：

```sh
rm -rf ~/.local/opt/ripgrep-* ~/.local/opt/fd-*
rm -f ~/.local/bin/rg ~/.local/bin/fd
```

Ubuntu 的 apt 包：

```sh
sudo apt remove ripgrep fd-find git curl
```

## 9. 常见问题

### 9.1 GitHub 下载失败

脚本需要访问 GitHub。配置代理后重试：

```sh
export HTTPS_PROXY=http://127.0.0.1:7897
export HTTP_PROXY=http://127.0.0.1:7897
```

### 9.2 Ubuntu apt 很慢

脚本使用 `Acquire::ForceIPv4`；如果仍然慢，检查软件源或代理。离线安装可以完全绕过这个问题。

### 9.3 `nvim` 版本不是 0.12.3

检查 PATH 顺序：

```sh
command -v nvim
~/.local/bin/nvim --version
```

如果系统里有旧版 `/usr/bin/nvim` 或 `/usr/local/bin/nvim`，把 `~/.local/bin` 放到 PATH 前面。

### 9.4 离线包架构不匹配

离线包里的 tarball 和 deb 都是架构相关的。Apple Silicon / Intel、x86_64 / arm64 不能混用；安装脚本会检查 `manifest.txt` 并报错。

## 10. 相关文档

- 测试方法：[`TESTING.md`](./TESTING.md)
- Neovim 配置：[`../nvim/README.md`](../nvim/README.md)
- 平台脚本约定：[`../platforms/README.md`](../platforms/README.md)
- Ubuntu 离线包：[`../platforms/linux/ubuntu/24.04/offline/README.md`](../platforms/linux/ubuntu/24.04/offline/README.md)
- macOS 离线包：[`../platforms/macos/offline/README.md`](../platforms/macos/offline/README.md)

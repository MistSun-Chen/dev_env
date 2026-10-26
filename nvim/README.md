# Neovim 配置

这是 `dev_env` 仓库中跨平台共用的 Neovim 配置。目标不是“装很多插件”，而是提供一套稳定、可迁移、在终端/SSH 下也能用的基础开发体验。

## 当前包含的功能

- leader 使用空格：`vim.g.mapleader = ' '`
- 混合行号：当前行显示绝对行号，其他行显示相对行号
- 智能大小写搜索：全小写忽略大小写，含大写字母时区分大小写
- 启动时关闭 intro 信息
- 鼠标在所有模式可用
- normal / insert 模式禁用方向键，提示改用 `hjkl`
- `Q` 保留 Neovim 默认行为（重复上一次录制的寄存器），没有禁用

插件：

- **lazy.nvim**：插件管理器，由 `lua/config/lazy.lua` 引导安装
- **fzf-lua**：找文件、全局/当前 buffer/选区/路径搜索、切换 buffer、最近文件
- **grug-far.nvim**：搜索并替换，支持项目、当前文件、选区范围和 glob/路径过滤
- **neo-tree.nvim**：侧边栏文件树，支持文件操作、Git 状态和诊断
- **nvim-lspconfig**：各语言 LSP server 的基础配置
- **lazydev.nvim**：让 LuaLS 识别 Neovim/Lua 插件 API
- **markview.nvim**：在 Neovim buffer 内渲染 Markdown
- **Catppuccin**：默认配色，提供 Mocha、Macchiato、Frappe、Latte 四种变体；运行时用 `<leader>tc` 切换
- **latex Tree-sitter parser**：markview 公式渲染所需，由本地脚本编译

插件管理链路：

```text
init.lua
└── config/lazy.lua          # 引导 lazy.nvim
    └── lazy.nvim            # 安装/加载其他插件
        ├── config/plugins.lua
        ├── fzf-lua
        ├── grug-far.nvim
        ├── neo-tree.nvim
        │   ├── nui.nvim
        │   └── plenary.nvim
        ├── nvim-lspconfig
        ├── lazydev.nvim
        ├── markview.nvim
        └── catppuccin
```

默认配色是 `catppuccin-mocha`；`<leader>tc` 会打开 Catppuccin 变体选择器，支持实时预览。

顶部 tabline 由内置 `tabline` 实现，显示所有已打开文件；文件树由 neo-tree 提供，Lua LSP 与原生补全已接入，Python/Bash 等 server 需要时再逐步补。

## 安装方式

Neovim 读取配置的位置可以用下面的命令确认：

```vim
:echo stdpath('config')
```

### macOS / Linux（推荐软链接）

把仓库里的 `nvim/` 目录链接到 Neovim 配置目录：

```sh
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
ln -sfn /path/to/dev_env/nvim "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
```

这样修改仓库里的 `init.lua` 后，下次启动 Neovim 就会生效。如果已经有旧配置，先备份或移走原目录。

Ubuntu 24.04 / macOS 可以直接使用安装脚本，脚本会自动处理配置链接、工具安装、插件安装和 `latex` parser 编译：

```sh
bash platforms/linux/ubuntu/24.04/install.sh
# 或
bash platforms/macos/install.sh
```

### 插件安装 / 更新

插件清单和版本在 `lua/config/plugins.lua`。lazy.nvim 自身固定到 `lua/config/lazy.lua` 中的 commit；fzf-lua、markview.nvim、grug-far.nvim、neo-tree.nvim、nvim-lspconfig、lazydev.nvim 及其依赖和配色插件的实际 revision 由 `lazy-lock.json` 固定。

```sh
# 联网安装缺失插件（首次安装或新增插件后）
bash nvim/scripts/install-plugins.sh

# 只检查已安装插件与 lockfile，不访问网络
bash nvim/scripts/install-plugins.sh --check

# 测试/离线 staging 时指定目录
NVIM_BIN=/path/to/nvim \
XDG_CONFIG_HOME=/path/to/config \
XDG_DATA_HOME=/path/to/data \
bash nvim/scripts/install-plugins.sh
```

脚本会：

1. 检查 `nvim`、`git`、`fzf`；
2. 必要时把 `~/.config/nvim` 链接到仓库；
3. 执行 `nvim --headless "+Lazy! install"`，由 lazy.nvim 安装缺失插件；
4. 检查 `lazy.nvim`、`fzf-lua`、`markview.nvim`、`grug-far.nvim`、`neo-tree.nvim`、`nui.nvim`、`plenary.nvim`、`nvim-lspconfig`、`lazydev.nvim`、配色插件目录和 `lazy-lock.json`；
5. 验证插件可以被 `require`。

插件安装位置：

```text
~/.local/share/nvim/lazy/lazy.nvim
~/.local/share/nvim/lazy/fzf-lua
~/.local/share/nvim/lazy/markview.nvim
~/.local/share/nvim/lazy/grug-far.nvim
~/.local/share/nvim/lazy/neo-tree.nvim
~/.local/share/nvim/lazy/nui.nvim
~/.local/share/nvim/lazy/plenary.nvim
~/.local/share/nvim/lazy/nvim-lspconfig
~/.local/share/nvim/lazy/lazydev.nvim
```

`lazy-lock.json` 位于配置目录（软链接模式下就是仓库的 `nvim/lazy-lock.json`），需要提交到 git。

已有插件需要升级时，在 Neovim 中执行：

```vim
:Lazy update fzf-lua markview.nvim grug-far.nvim neo-tree.nvim nui.nvim plenary.nvim nvim-lspconfig lazydev.nvim
```

这样只更新这些插件，不会顺带移动 lazy.nvim 自身的固定 commit。

公式渲染还需要：

```sh
bash nvim/scripts/build-latex-parser.sh
```

该脚本需要 `tree-sitter` CLI、C 编译器和 Node.js；Node 只用于 `tree-sitter generate` 生成 parser.c，不是 Neovim 运行时依赖。平台安装脚本会自动安装；离线包会在下载端预编译 `latex.so`，目标端不需要编译器和 Node。

### Windows（推荐复制或目录联接）

Neovim 在 Windows 上通常读取 `stdpath('config')` 返回的目录（常见为 `~/AppData/Local/nvim`）。可以把本目录复制过去：

```powershell
$dst = "$env:LOCALAPPDATA\nvim"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force .\nvim\* $dst
```

如果希望仓库修改自动同步，可以在有权限的情况下使用目录联接（junction）：

```powershell
New-Item -ItemType Junction -Path "$env:LOCALAPPDATA\nvim" -Target "C:\path\to\dev_env\nvim"
```

Windows 安装脚本尚未实现；当前以复制方式为准，后续会在 `platforms/windows/` 中补充。

## 键位

完整键位（含 LSP 默认键位、grug-far/neo-tree/fzf 内部键位）见 [`keymaps.md`](./keymaps.md)。

| 键位 | 功能 |
|---|---|
| `<leader>ff` | 查找文件 |
| `<leader>fg` | 全局搜索（rg）；可输入 `query -- glob` 限定文件 |
| `<leader>fc` | 当前 buffer 搜索 |
| `<leader>fw` | 搜索光标下单词 |
| `<leader>fs` | 按路径 + glob 搜索，`!` 开头排除 |
| `<leader>fv` | visual 模式搜索选中文本 |
| `<leader>bs` | 打开 buffer 列表并切换 |
| `<leader>fr` | 最近文件 |
| `<leader>bn` | 下一个 buffer |
| `<leader>bp` | 上一个 buffer |
| `<leader>bd` | 关闭当前 buffer |
| `<leader>et` | 文件树开关（explorer toggle），打开时定位当前文件 |
| `<leader>sr` | 搜索并替换（grug-far）；visual 模式限制在选区内 |
| `<leader>sR` | 当前文件搜索并替换 |
| `<leader>mt` | Markdown 目录（按标题跳转） |
| `<leader>mp` | Markdown 预览开关 |
| `<leader>ms` | Markdown 分屏预览 |
| `<leader>tc` | 选择配色方案（theme change） |

说明：

- grug-far 内部用 `<localleader>`（这里也是空格）：`<Tab>` 切换输入框，`<Space>r` 执行 Replace，`<Space>c` 关闭，`<Space>i` 预览；`Paths` 是搜索路径，`Files Filter` 是文件 glob，`Flags` 是额外 rg 参数，正常替换不需要 `Sync`。`<Esc>` 只退出插入模式，不关闭 grug-far。
- grug-far 结果区用 `j` / `k` 移动；`<Up>` / `<Down>` 打开的是匹配所在的**原文件预览**，不是 diff。替换前后的差异在结果区显示（默认 `showReplaceDiff`）。
- 顶部 tabline 显示已打开文件；左键点击切换，`<leader>bn` / `<leader>bp` 上一个/下一个，`<leader>bd` 关闭。`<leader>bs` 按 buffer 名称/路径过滤，不搜内容。
- 文件树用 `<leader>et` 开关；打开时会跟随并定位当前文件。文件树内的展开/折叠、新建、重命名等使用 neo-tree 默认键位，可用 `?` 查看。
- 文件树里的 `/` 是 neo-tree 的递归模糊过滤，不是 fzf：用 `<C-j>` / `<C-k>`（或 `<C-n>` / `<C-p>` / 方向键）移动，`<Enter>` 打开。要按文件名快速全局跳转仍用 `<leader>ff`；大项目里 `/` 慢的话可以用 `f`（输入完按 Enter 才过滤）。
- 文件树宽度默认 32；路径层级变深时会自动加宽（`auto_expand_width`），只增不减，不会自动缩回。
- fzf 列表里用 `<C-j>` / `<C-k>`（或方向键）移动，`<Enter>` 打开，`<Esc>` 取消；buffer picker 顶部也会显示这行提示。

## LSP

当前只启用 Lua（`lua_ls`）。插件由 lazy.nvim 安装，但 **language server 需要手动安装**，平台安装脚本和离线包暂不包含它。

手动安装 `lua-language-server`（以 Apple Silicon macOS 为例）：

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

Linux 或 Intel Mac 把压缩包名换成对应平台即可；确保 `~/.local/bin` 在 `PATH` 中。

> 不要直接给 `~/.local/bin/lua-language-server` 建符号链接：LuaLS 的 bootstrap 二进制会按自身路径查找 `main.lua`，经符号链接启动时会去 `~/.local/bin/main.lua` 找而失败，所以这里用绝对路径的 wrapper。

LSP 键位：

| 键位 | 功能 |
|---|---|
| `gd` | 跳转定义 |
| `K` | 悬停文档 |
| `grn` | 重命名 |
| `grr` | 查看引用 |
| `gri` | 查看实现 |
| `gra` | code action |
| `[d` / `]d` | 上一个/下一个诊断 |
| `<leader>ld` | 当前文件诊断列表（fzf-lua） |
| `<leader>ls` | 当前文件符号列表（fzf-lua） |

补全使用 Neovim 原生 `vim.lsp.completion`：`<C-n>` / `<C-p>` 选择，`<C-y>` 接受，`<C-x><C-o>` 手动触发。诊断默认显示在行内，`<leader>ld` 可打开列表。

说明：

- LuaLS 首次打开项目时需要索引；索引完成前 `K` 可能显示 `Workspace loading` 或暂时没有结果，稍等几秒再试。
- `grn` 只对 LuaLS 判断为可重命名的符号生效；在 `vim` 这类全局符号上会提示无法重命名。局部变量只改当前作用域；模块字段/导出函数可能跨文件，改的是 LSP 引用而不是文本匹配，建议先用 `grr` 看引用范围。
- `gra` 只在当前位置确实有 code action 时才有内容；LuaLS 提供的 action 较少，提示 `No code actions available` 属于正常现象。例如 `local x = missing_name` 出现未定义全局诊断后，光标放到 `missing_name` 上按 `gra`，会出现 `Mark missing_name as defined global`、`Disable diagnostics on this line` 等选项。

验证：

```vim
:checkhealth vim.lsp
:LspInfo
```

命令：

- `:Markview` / `:Markview Toggle`：markview 预览开关（所有已附加 buffer）
- `:Markview toggle` / `:Markview disable` / `:Markview enable`：只控制当前 buffer
- `:Markview splitToggle`：分屏预览

## Markdown 预览与目录

- Markdown 标题、表格、代码块、引用、链接在 buffer 内渲染。
- 行内公式 `$...$` 和块公式 `$$...$$` 通过 markview 转成 Unicode 近似显示。
- `mermaid` 代码块按普通代码块显示，不做渲染；需要查看图表时使用外部工具。

如果只想看原始 Markdown：

- `<leader>mp` / `:Markview Toggle`：开关 markview 渲染（所有已附加 buffer）；
- `:Markview toggle`：只开关当前 buffer 的 markview 渲染。

### 目录跳转

`<leader>mt` 使用内置 markdown Tree-sitter parser 收集 ATX 标题（`#`、`##` 等），再用 fzf-lua 选择并跳转；不需要额外插件。

markdown 文档内的 `[标题](#anchor)` 链接也可以用 `gx` 跳转（markview 的 `preview.map_gx` 默认开启）。

## 配色方案

默认：

```text
catppuccin-mocha
```

可用变体：

| 配色名 | 说明 |
|---|---|
| `catppuccin-mocha` | 默认，深色 |
| `catppuccin-macchiato` | 深色，略偏灰 |
| `catppuccin-frappe` | 深色，柔和 |
| `catppuccin-latte` | 浅色 |

切换：

```vim
:FzfLua colorschemes
```

或按 `<leader>tc`。选择器只列出 Catppuccin 的四个变体，并支持实时预览；当前选择只在本次会话生效，重启后回到 `catppuccin-mocha`。

限制：

- 公式是 Unicode 近似，不是 TeX 排版；矩阵、复杂积分等可能不理想。

## 验证

启动 Neovim 后检查：

```vim
:set number? relativenumber? ignorecase? smartcase? mouse? shortmess?
:Lazy
:checkhealth markview
```

- `number`、`relativenumber`、`ignorecase`、`smartcase` 应为开启
- `mouse` 应为 `a`
- `shortmess` 应包含 `I`
- normal / insert 模式按方向键，应出现 `Use h/l/k/j` 提示
- 按 `Q` 不应当被禁用；它保留 Neovim 默认行为
- 按 `<leader>et` 应打开/关闭左侧文件树，并定位当前文件
- 打开一个 Lua 文件，`:LspInfo` 应显示 `lua_ls`；`K` / `gd` / `grr` 应可用
- 打开一个 Markdown 文件，按 `<leader>mt` 应弹出标题选择器
- 按 `<leader>tc` 应打开配色选择器，并可以实时预览
- `mermaid` 代码块按普通代码块显示，不出现图表或额外提示

## 修改约定

- 所有解释性注释使用中文。
- 不写死 `/Users/...`、`/home/...`、`C:\...` 等平台路径。
- 平台相关逻辑放到 `platforms/<os>/`，配置本身尽量保持跨平台。
- 修改后提交到 `dev_env`；使用软链接的机器不需要重新安装。
- 插件版本改动后运行 `install-plugins.sh`，把新的 `lazy-lock.json` 一并提交。
- 升级 lazy.nvim 自身时修改 `lua/config/lazy.lua` 的 `lazy_commit`，并删除旧目录后重新启动。
- 离线包不提交到 git；只提交生成/安装脚本和 lockfile。

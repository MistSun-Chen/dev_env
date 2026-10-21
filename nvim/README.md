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
- **fzf-lua**：找文件、全局搜索、切换 buffer、最近文件
- **markview.nvim**：在 Neovim buffer 内渲染 Markdown
- **mermaid-ascii**：把 `mermaid` 代码块渲染成终端文本图（独立二进制，不是 Neovim 插件）
- **latex Tree-sitter parser**：markview 公式渲染所需，由本地脚本编译

插件管理链路：

```text
init.lua
└── config/lazy.lua          # 引导 lazy.nvim
    └── lazy.nvim            # 安装/加载其他插件
        ├── config/plugins.lua
        ├── fzf-lua
        └── markview.nvim
```

文件树、LSP、补全等仍未加入；需要时再逐步补。

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

插件清单和版本在 `lua/config/plugins.lua`。lazy.nvim 自身固定到 `lua/config/lazy.lua` 中的 commit；fzf-lua 和 markview.nvim 的实际 revision 由 `lazy-lock.json` 固定。

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
4. 检查 `lazy.nvim`、`fzf-lua`、`markview.nvim` 目录和 `lazy-lock.json`；
5. 验证插件可以被 `require`。

插件安装位置：

```text
~/.local/share/nvim/lazy/lazy.nvim
~/.local/share/nvim/lazy/fzf-lua
~/.local/share/nvim/lazy/markview.nvim
```

`lazy-lock.json` 位于配置目录（软链接模式下就是仓库的 `nvim/lazy-lock.json`），需要提交到 git。

已有插件需要升级时，在 Neovim 中执行：

```vim
:Lazy update fzf-lua markview.nvim
```

这样只更新这两个插件，不会顺带移动 lazy.nvim 自身的固定 commit。

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

| 键位 | 功能 |
|---|---|
| `<leader>ff` | 查找文件 |
| `<leader>fg` | 全局搜索（rg） |
| `<leader>fb` | 切换 buffer |
| `<leader>fr` | 最近文件 |
| `<leader>mp` | Markdown 预览开关 |
| `<leader>ms` | Markdown 分屏预览 |
| `<leader>mm` | 重新渲染 Mermaid 代码块 |

命令：

- `:Markview` / `:Markview Toggle`：markview 预览开关
- `:Markview splitToggle`：分屏预览
- `:MermaidRender`：重新渲染当前 Markdown 的 Mermaid 块
- `:MermaidClear`：清除 Mermaid 文本图

## Markdown 预览能力

- Markdown 标题、表格、代码块、引用、链接在 buffer 内渲染。
- 行内公式 `$...$` 和块公式 `$$...$$` 通过 markview 转成 Unicode 近似显示。
- `mermaid` 代码块通过 `mermaid-ascii` 渲染成 Unicode/ASCII 文本图，显示在代码块下方。
- 支持常见的 Mermaid `graph` / `flowchart`、`sequenceDiagram`、`erDiagram`。
- `stateDiagram`、`classDiagram`、`gantt`、`pie`、`timeline` 等暂不支持，会保留源码并显示提示。

限制：

- 公式是 Unicode 近似，不是 TeX 排版；矩阵、复杂积分等可能不理想。
- Mermaid 是文本图，窄终端会自动压缩或提示。
- 需要高保真 KaTeX/Mermaid 时，可以以后增加可选的浏览器预览；当前配置优先保证 SSH/无 GUI 终端可用。

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
- 打开一个 Markdown 文件，按 `<leader>mp` 应切换渲染
- 在 `mermaid` 代码块上按 `<leader>mm`，代码块下方应出现文本图

## 修改约定

- 所有解释性注释使用中文。
- 不写死 `/Users/...`、`/home/...`、`C:\...` 等平台路径。
- 平台相关逻辑放到 `platforms/<os>/`，配置本身尽量保持跨平台。
- 修改后提交到 `dev_env`；使用软链接的机器不需要重新安装。
- 插件版本改动后运行 `install-plugins.sh`，把新的 `lazy-lock.json` 一并提交。
- 升级 lazy.nvim 自身时修改 `lua/config/lazy.lua` 的 `lazy_commit`，并删除旧目录后重新启动。
- 离线包不提交到 git；只提交生成/安装脚本和 lockfile。

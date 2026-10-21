# 使用与安装

本文是 `dev_env` 的使用说明。README 只保留入口和概览。

## 1. 仓库提供什么

每个平台安装以下工具：

- Neovim 0.12.x
- ripgrep（`rg`）
- fd
- fzf
- git（`lazy.nvim` 引导和插件安装需要）
- `mermaid-ascii`（终端 Mermaid 文本图）
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

- apt 安装 `ca-certificates`、`curl`、`git`、`ripgrep`、`fd-find`、`gcc`、`libc6-dev`、`unzip`、`nodejs`；
- 补 `~/.local/bin/fd -> fdfind`；
- 从官方 release 安装 Neovim 0.12.3、fzf 0.74.5、mermaid-ascii 1.6.1、tree-sitter 0.27.1，并校验 SHA256；
- 备份并链接 `~/.config/nvim -> <repo>/nvim`；
- 调用 `nvim/scripts/install-plugins.sh` 安装插件，调用 `build-latex-parser.sh` 编译公式 parser。

macOS：

- 缺失时用 Homebrew 安装 `ripgrep`、`fd`、`git`、`node`；
- 从官方 release 安装 Neovim 0.12.3、fzf 0.74.5、mermaid-ascii 1.6.1、tree-sitter 0.27.1，并校验 SHA256；
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
- `fzf-lua`
- `markview.nvim`
- `catppuccin` 配色插件

插件安装位置：

```text
~/.local/share/nvim/lazy/lazy.nvim
~/.local/share/nvim/lazy/fzf-lua
~/.local/share/nvim/lazy/markview.nvim
~/.local/share/nvim/lazy/catppuccin
```

`lazy-lock.json` 位于配置目录，软链接模式下就是仓库的 `nvim/lazy-lock.json`，需要提交到 git。lazy.nvim 自身固定到 `nvim/lua/config/lazy.lua` 中的 commit，升级时修改该常量并删除旧插件目录后重新启动。

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

### 3.3 Markdown 预览

打开 Markdown 文件后：

| 键位/命令 | 功能 |
|---|---|
| `<leader>mt` | Markdown 标题目录选择器 |
| `<leader>mp` / `:Markview Toggle` | 当前 buffer 预览开关 |
| `<leader>ms` / `:Markview splitToggle` | 分屏预览 |
| `<leader>mm` / `:MermaidRender` | 重新渲染 Mermaid 块 |
| `<leader>uc` / `:FzfLua colorschemes` | 切换 Catppuccin 变体 |

默认配色是 `catppuccin-mocha`；配色切换只在当前 Neovim 会话生效。
| `:MermaidClear` | 清除 Mermaid 文本图 |

能力与限制：

- 标题、表格、代码块、引用、链接在 buffer 内渲染；
- `$...$` / `$$...$$` 由 markview 转成 Unicode 近似公式；
- `graph` / `flowchart`、`sequenceDiagram`、`erDiagram` 渲染为终端文本图；
- 其他 Mermaid 类型保留源码并提示；
- 不依赖浏览器，SSH/无 GUI 终端可用；
- 公式不是 TeX 排版，复杂公式可能不理想；
- Mermaid 是文本图，窄终端会压缩或提示。

需要高保真 KaTeX/Mermaid 时，后续可增加可选浏览器预览；它不是当前默认方案。

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

- 离线包包含 apt deb、Neovim、fzf、mermaid-ascii、tree-sitter、Neovim 插件、预编译 `latex.so`、Neovim 配置和 `SHA256SUMS`；
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

- 离线包包含 Neovim、fzf、ripgrep、fd、mermaid-ascii、tree-sitter、Neovim 插件、预编译 `latex.so`、Neovim 配置和 `SHA256SUMS`；
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
nvim --headless "+lua assert(pcall(require,'lazy')); assert(pcall(require,'fzf-lua')); assert(pcall(require,'markview')); assert(vim.treesitter.language.add('latex'))" +qa
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

修改 `NVIM_VERSION` / `FZF_VERSION` / `RG_VERSION` / `FD_VERSION` / `MERMAID_ASCII_VERSION` / `TREE_SITTER_VERSION` 时，必须同步更新对应的 SHA256，否则下载会校验失败。修改 tree-sitter-latex 版本时，同步更新 `nvim/scripts/versions.env` 中的 URL/commit/SHA256，并重新生成离线包。

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
rm -rf ~/.local/opt/mermaid-ascii-1.6.1 ~/.local/opt/tree-sitter-0.27.1
rm -f ~/.local/bin/nvim ~/.local/bin/fzf ~/.local/bin/mermaid-ascii ~/.local/bin/tree-sitter

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

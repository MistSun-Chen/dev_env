# Neovim 脚本

这些脚本由平台安装脚本调用，也可以单独运行。

## install-plugins.sh

```sh
bash nvim/scripts/install-plugins.sh
bash nvim/scripts/install-plugins.sh --check
```

- 无参数：联网安装缺失的 lazy.nvim 插件，并验证 `lazy`、`which-key`、`gitsigns`、`fzf-lua`、`markview`、`grug-far`、`neo-tree`、`nvim-lspconfig`、`lazydev` 以及配色插件。已有插件的更新使用 `:Lazy update which-key.nvim gitsigns.nvim fzf-lua markview.nvim grug-far.nvim neo-tree.nvim nui.nvim plenary.nvim nvim-lspconfig lazydev.nvim`。
- `--check`：只检查配置目录、`lazy-lock.json`、插件目录和 `require`，用于离线安装和 CI。
- 可通过 `NVIM_BIN`、`XDG_CONFIG_HOME`、`XDG_DATA_HOME` 覆盖路径，适合临时环境。
- lazy.nvim 自身由 `nvim/lua/config/lazy.lua` 引导，固定到该文件中的 commit。
- 插件版本来自 `nvim/lua/config/plugins.lua`，实际 revision 由 `nvim/lazy-lock.json` 固定。
- 插件目录位于 `$XDG_DATA_HOME/nvim/lazy/`（默认 `~/.local/share/nvim/lazy/`）。
- 本脚本只安装 Neovim 插件，不安装 language server；`lua-language-server` 需要按 `nvim/README.md` 手动准备，pyright/bashls/clangd 可用 `install-lsp.sh`。

## install-lsp.sh

```sh
bash nvim/scripts/install-lsp.sh --components python,cpp,bash
bash nvim/scripts/install-lsp.sh --all
bash nvim/scripts/install-lsp.sh --none
```

- 在线安装 pyright 1.1.414、bash-language-server 5.6.0 和 clangd；版本在 `versions.env` 固定。bashls 5.8.1 要求 Node >=20，Ubuntu 24.04 的 Node 18 不满足，所以固定 5.6.0。
- npm server 安装到 `~/.local/opt`，不使用 `npm -g`，并在 `~/.local/bin` 生成 wrapper。
- Ubuntu 的 clangd 通过 apt 安装（需要 sudo），并补 `g++`；macOS 使用 Xcode CLT 的 clangd。
- 幂等：已有 server 会跳过；未选择任何组件时直接退出。

## install-mermaid-ascii.sh

```sh
bash nvim/scripts/install-mermaid-ascii.sh
```

安装 `mermaid-ascii` 1.6.2 单文件二进制到 `~/.local/opt/mermaid-ascii-1.6.2`，并链接到 `~/.local/bin/mermaid-ascii`。支持 macOS arm64/x86_64 和 Linux arm64/x86_64；版本和 SHA256 固定在 [`versions.env`](./versions.env)。它不需要浏览器、Node、ImageMagick 或 Neovim 插件，是 Neovim 内 Mermaid ASCII 预览的运行时依赖。平台在线安装器会调用本脚本；离线包内置对应平台的 tarball，由离线安装器直接解压，不访问网络。脚本可重复执行，同版本已安装时只修复链接。

## mermaid-view.sh

```sh
bash nvim/scripts/mermaid-view.sh -n 1 docs/example.md
COLS=200 bash nvim/scripts/mermaid-view.sh -n 2 docs/example.md
```

从 Markdown 中提取第 N 个 ` ```mermaid ` 块并输出 ASCII。只依赖 `mermaid-ascii`；在 shell 里查看时可以用 `COLS` 控制宽度。Neovim 内对应 `<leader>mb`（宽图横向滚动）和 normal 模式的自动 ASCII 预览。

## check-lsp.sh

```sh
bash nvim/scripts/check-lsp.sh
bash nvim/scripts/check-lsp.sh --strict
```

只读检查 LSP server、Node/npm、C/C++ 编译器、Linux 标准头文件和可选的 `shellcheck`，不会安装任何东西。默认始终返回 0；`--strict` 在有必需项缺失时返回 1。

## build-latex-parser.sh

```sh
bash nvim/scripts/build-latex-parser.sh
```

编译 `latex-lsp/tree-sitter-latex` 并安装到：

```text
${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/parser/latex.so
```

依赖 `tree-sitter` CLI、C 编译器（macOS `cc`，Ubuntu `gcc`）和 Node.js（`tree-sitter generate` 需要；不是 Neovim 运行时依赖）。版本和源码 SHA256 固定在 `versions.env`。

## stage-plugins.sh

```sh
bash nvim/scripts/stage-plugins.sh --output /tmp/bundle
```

供离线包 `download.sh` 使用：在临时 `XDG_*` 目录中安装 lazy.nvim 插件、编译 latex parser，然后把以下产物放到输出目录：

```text
nvim-plugins/       # lazy.nvim 根目录，含 lazy.nvim、which-key.nvim、gitsigns.nvim、fzf-lua、markview.nvim、grug-far.nvim、neo-tree.nvim、nui.nvim、plenary.nvim、nvim-lspconfig、lazydev.nvim、配色插件 和 .git
nvim-parser/latex.so
nvim/lazy-lock.json
```

注意：插件目录必须复制，不能建符号链接；lazy.nvim 需要真实的 git 仓库目录。

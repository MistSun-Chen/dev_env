# Neovim 脚本

这些脚本由平台安装脚本调用，也可以单独运行。

## install-plugins.sh

```sh
bash nvim/scripts/install-plugins.sh
bash nvim/scripts/install-plugins.sh --check
```

- 无参数：联网安装缺失的 lazy.nvim 插件，并验证 `lazy`、`fzf-lua`、`markview`、`grug-far` 以及配色插件。已有插件的更新使用 `:Lazy update fzf-lua markview.nvim grug-far.nvim`。
- `--check`：只检查配置目录、`lazy-lock.json`、插件目录和 `require`，用于离线安装和 CI。
- 可通过 `NVIM_BIN`、`XDG_CONFIG_HOME`、`XDG_DATA_HOME` 覆盖路径，适合临时环境。
- lazy.nvim 自身由 `nvim/lua/config/lazy.lua` 引导，固定到该文件中的 commit。
- 插件版本来自 `nvim/lua/config/plugins.lua`，实际 revision 由 `nvim/lazy-lock.json` 固定。
- 插件目录位于 `$XDG_DATA_HOME/nvim/lazy/`（默认 `~/.local/share/nvim/lazy/`）。

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
nvim-plugins/       # lazy.nvim 根目录，含 lazy.nvim、fzf-lua、markview.nvim、grug-far.nvim、配色插件 和 .git
nvim-parser/latex.so
nvim/lazy-lock.json
```

注意：插件目录必须复制，不能建符号链接；lazy.nvim 需要真实的 git 仓库目录。

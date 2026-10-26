# macOS 平台

已实现联网安装和离线安装，支持 Apple Silicon（`arm64`）和 Intel（`x86_64`）。

## 联网安装

```sh
bash platforms/macos/install.sh
```

要求：

- macOS
- Homebrew（用于 `ripgrep`、`fd`、`git`）
- 能访问 GitHub

安装内容：

| 工具 | 来源 | 说明 |
|---|---|---|
| Neovim 0.12.3 | 官方 macOS tarball | `~/.local/opt/nvim-0.12.3`，链接到 `~/.local/bin/nvim` |
| fzf 0.74.5 | 官方 macOS tarball | `~/.local/opt/fzf-0.74.5`，链接到 `~/.local/bin/fzf` |
| ripgrep | Homebrew（缺失时） | `brew install ripgrep` |
| fd | Homebrew（缺失时） | `brew install fd` |
| git | Homebrew（缺失时） | `brew install git` |
| tree-sitter CLI 0.27.1 | 官方 macOS zip | `~/.local/opt/tree-sitter-0.27.1` |
| Node.js | Homebrew（缺失时） | 仅用于构建 latex parser |

脚本会安装 lazy.nvim 及其管理的插件（fzf-lua、markview、grug-far、neo-tree、nvim-lspconfig、lazydev、配色），并编译 `latex` parser。Lua language server 需要按 `nvim/README.md` 的 LSP 一节手动安装。然后把：

```text
~/.config/nvim  ->  <repo>/nvim
```

已有配置会先备份为 `~/.config/nvim.bak.YYYYMMDD-HHMMSS`。

只安装工具、不接管配置：

```sh
bash platforms/macos/install.sh --skip-config
```

## 离线安装

在联网 Mac 上下载离线包：

```sh
cd platforms/macos/offline
bash download.sh
```

产物：

```text
offline/dist/
offline/dev_env-macos-<arch>.tar.gz
```

把压缩包拷到离线 Mac，解压后：

```sh
bash install.sh
```

离线包包含 Neovim、fzf、ripgrep、fd、tree-sitter、Neovim 插件、预编译 `latex.so` 和 Neovim 配置；不包含 Homebrew 和 git。详见 [`offline/README.md`](./offline/README.md)。

## 验证

```sh
nvim --version | head -1
rg --version | head -1
fd --version
fzf --version
git --version
tree-sitter --version
```

## 注意

- Apple Silicon 的 Homebrew 前缀通常是 `/opt/homebrew`；Intel 通常是 `/usr/local`。
- `~/.local/bin` 需要在 PATH 中；脚本会检查并提示。
- 如果系统里已有 `/usr/local/bin/nvim`，它可能比 `~/.local/bin` 更早被解析；脚本会跳过已满足版本要求的 Neovim，并打印实际版本。

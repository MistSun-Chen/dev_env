# macOS 平台

已实现联网安装和离线安装，支持 Apple Silicon（`arm64`）和 Intel（`x86_64`）。

## 联网安装

```sh
bash platforms/macos/install.sh
```

要求：

- macOS
- Homebrew（用于 `ripgrep`、`fd`、`git`、`tmux`）
- 能访问 GitHub

安装内容：

| 工具 | 来源 | 说明 |
|---|---|---|
| Neovim 0.12.3 | 官方 macOS tarball | `~/.local/opt/nvim-0.12.3`，链接到 `~/.local/bin/nvim` |
| fzf 0.74.5 | 官方 macOS tarball | `~/.local/opt/fzf-0.74.5`，链接到 `~/.local/bin/fzf` |
| tmux | Homebrew（缺失时） | `--pinned-tmux` 可改为固定 3.8 自包含构建 |
| Starship 1.27.0 | 官方 macOS tarball | `~/.local/opt/starship-1.27.0` |
| Meslo Nerd Font 3.5.1 | Nerd Fonts release | 四个样式安装到 `~/Library/Fonts` |
| ripgrep | Homebrew（缺失时） | `brew install ripgrep` |
| fd | Homebrew（缺失时） | `brew install fd` |
| git | Homebrew（缺失时） | `brew install git` |
| tree-sitter CLI 0.27.1 | 官方 macOS zip | `~/.local/opt/tree-sitter-0.27.1` |
| Node.js | Homebrew（缺失时） | 仅用于构建 latex parser |

脚本会安装 lazy.nvim 及其管理的插件（which-key、gitsigns、fzf-lua、markview、grug-far、neo-tree、nvim-lspconfig、lazydev、配色），并编译 `latex` parser。Lua/Python/Bash language server 需要按 `nvim/README.md` 的 LSP 一节手动安装；C/C++ 的 `clangd` 通常由 Xcode Command Line Tools 提供。然后把：

```text
~/.config/nvim         ->  <repo>/nvim
~/.config/tmux/tmux.conf -> <repo>/tmux/tmux.conf
~/.zshrc               ->  <repo>/shell/zshrc
~/.config/starship.toml -> <repo>/shell/starship.toml
```

已有配置会先备份为 `*.bak.YYYYMMDD-HHMMSS`；`~/.zshrc.local` 不存在时创建为权限 600。

只安装工具、不接管配置：

```sh
bash platforms/macos/install.sh --skip-config
```

只跳过 shell 配置：

```sh
bash platforms/macos/install.sh --skip-shell
```

固定 tmux 版本：

```sh
bash platforms/macos/install.sh --pinned-tmux
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

离线包包含 Neovim、fzf、ripgrep、fd、tree-sitter、tmux 3.8 自包含二进制、Starship、Meslo 字体、Neovim/tmux/shell 配置、Neovim 插件和预编译 `latex.so`；不包含 Homebrew、编译器和 git。详见 [`offline/README.md`](./offline/README.md)。

## 验证

```sh
nvim --version | head -1
tmux -V
zsh --version
starship --version
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

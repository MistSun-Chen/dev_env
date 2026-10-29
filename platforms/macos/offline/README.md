# macOS 离线安装

适用场景：目标 Mac 不能联网，但可以拷入离线包。

离线包包含：

- `nvim-macos-*.tar.gz`：Neovim 0.12.3
- `fzf-*-darwin_*.tar.gz`：fzf 0.74.5
- `ripgrep-*-apple-darwin.tar.gz`：ripgrep 15.2.0
- `fd-v*-apple-darwin.tar.gz`：fd 10.5.0
- `tree-sitter-cli-macos-*.zip`：tree-sitter CLI 0.27.1
- `starship-*-apple-darwin.tar.gz`：Starship 1.27.0
- `Meslo.tar.xz`：Nerd Fonts 3.5.1 Meslo
- `tmux-bin`、`tmux-build-info.txt`：自包含 tmux 3.8
- `nvim-plugins/`：lazy.nvim 根目录，含 lazy.nvim、which-key.nvim、gitsigns.nvim、fzf-lua、markview.nvim、grug-far.nvim、neo-tree.nvim、nui.nvim、plenary.nvim、nvim-lspconfig、lazydev.nvim、配色插件（均带 `.git`）
- `nvim-parser/latex.so`：预编译公式 parser
- `nvim/`、`tmux/`、`shell/`：配置与 lockfile
- `lib/common.sh`：配置部署 helper
- `install.sh`：离线安装脚本
- `versions.env`、`manifest.txt`、`SHA256SUMS`

> 离线包不包含 `git`。macOS 上通常已有 Xcode Command Line Tools 提供的 `git`；如果没有，离线安装会给出提示。

## 1. 在联网 Mac 上下载

要求：

- macOS
- 架构与目标机器一致（Apple Silicon `arm64` 或 Intel `x86_64`）
- 能访问 GitHub
- 构建机需要 Node.js、Xcode Command Line Tools（`cc`）和 `make`；用于编译 latex parser 和自包含 tmux。目标机不需要这些工具。

```sh
cd platforms/macos/offline
bash download.sh
```

产物：

```text
offline/dist/
offline/dev_env-macos-<arch>.tar.gz
```

如果网络需要代理：

```sh
https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897 bash download.sh
```

只生成目录、不打包：

```sh
bash download.sh --no-tar
```

输出目录默认是 `offline/dist/`。如果目录非空且不是之前生成的 dev_env 离线包，
脚本会拒绝覆盖；确认可以清空时加 `--force`：

```sh
bash download.sh --output /tmp/dev_env-bundle --force
```

## 2. 拷贝到离线 Mac

```sh
tar -xzf dev_env-macos-<arch>.tar.gz
cd dev_env-macos-<arch>
bash install.sh
```

或直接拷贝整个 `offline/dist/` 目录，进入目录执行：

```sh
bash install.sh
```

## 3. 验证

```sh
~/.local/bin/nvim --version | head -1
~/.local/bin/tmux -V
zsh --version
~/.local/bin/starship --version
~/.local/bin/fzf --version
~/.local/bin/rg --version | head -1
~/.local/bin/fd --version
git --version
```

## 选项

```sh
bash install.sh --skip-config   # 只装工具；不链接配置，也不修改已有 Neovim 插件/parser
bash install.sh --skip-shell    # 只跳过 shell 配置
```

## 配置副本

安装时会把包内的 `nvim/`、`tmux/`、`shell/` 复制到：

```text
${XDG_DATA_HOME:-$HOME/.local/share}/dev_env/config/
```

`~/.zshrc`、`~/.config/nvim`、`~/.config/tmux/tmux.conf` 等链接到这个稳定副本。
因此安装完成后可以删除解压出来的离线包目录，不会让配置变成悬空软链接。

## 注意事项

- 架构必须一致：Apple Silicon 和 Intel 的 tarball、tmux 二进制不能混用。
- 已有 `~/.config/nvim`、`~/.config/tmux/tmux.conf`、`~/.zshrc` 会先备份。
- 离线包不包含 Homebrew 或编译器；tmux 是预构建自包含二进制。
- 安装位置是 `~/.local/opt/`，命令链接到 `~/.local/bin/`。
- 终端配色只复制到 `~/.local/share/dev_env/terminal/`，不会自动修改 iTerm2/Terminal 偏好。
- 离线包默认不提交到 git（见 `.gitignore`）。

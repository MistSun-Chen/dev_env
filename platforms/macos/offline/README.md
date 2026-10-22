# macOS 离线安装

适用场景：目标 Mac 不能联网，但可以拷入离线包。

离线包包含：

- `nvim-macos-*.tar.gz`：Neovim 0.12.3
- `fzf-*-darwin_*.tar.gz`：fzf 0.74.5
- `ripgrep-*-apple-darwin.tar.gz`：ripgrep 15.2.0
- `fd-v*-apple-darwin.tar.gz`：fd 10.5.0
- `tree-sitter-cli-macos-*.zip`：tree-sitter CLI 0.27.1
- `nvim-plugins/`：lazy.nvim 根目录，含 lazy.nvim、fzf-lua、markview.nvim、grug-far.nvim、配色插件（均带 `.git`）
- `nvim-parser/latex.so`：预编译公式 parser
- `nvim/`：Neovim 配置与 lockfile
- `install.sh`：离线安装脚本
- `versions.env`、`manifest.txt`、`SHA256SUMS`

> 离线包不包含 `git`。macOS 上通常已有 Xcode Command Line Tools 提供的 `git`；如果没有，离线安装会给出提示。

## 1. 在联网 Mac 上下载

要求：

- macOS
- 架构与目标机器一致（Apple Silicon `arm64` 或 Intel `x86_64`）
- 能访问 GitHub
- 构建机需要 Node.js 和 Xcode Command Line Tools（`cc`），仅用于编译 latex parser

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
~/.local/bin/fzf --version
~/.local/bin/rg --version | head -1
~/.local/bin/fd --version
git --version
```

## 选项

```sh
bash install.sh --skip-config   # 只装工具，不接管 Neovim 配置
```

## 注意事项

- 架构必须一致：Apple Silicon 和 Intel 的 tarball 不能混用。
- 已有 `~/.config/nvim` 会先备份为 `~/.config/nvim.bak.YYYYMMDD-HHMMSS`。
- 离线包不包含 Homebrew，也不修改 shell 配置。
- 安装位置是 `~/.local/opt/`，命令链接到 `~/.local/bin/`。
- 离线包默认不提交到 git（见 `.gitignore`）。

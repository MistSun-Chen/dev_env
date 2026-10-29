# Ubuntu 24.04 离线安装

适用场景：目标机器**不能联网**，但可以拷入一个离线包。

离线包包含：

- `debs/`：`ca-certificates`、`curl`、`git`、`ripgrep`、`fd-find`、`tmux`、`zsh`、`ncurses-term`、`xz-utils` 及其依赖
- `nvim-linux-*.tar.gz`：Neovim 官方二进制
- `fzf-*-linux_*.tar.gz`：fzf 官方二进制
- `tree-sitter-cli-linux-*.zip`：tree-sitter CLI
- `starship-*-unknown-linux-musl.tar.gz`：Starship 1.27.0
- `Meslo.tar.xz`：Nerd Fonts 3.5.1 Meslo
- `nvim-plugins/`：lazy.nvim 根目录，含 lazy.nvim、which-key.nvim、gitsigns.nvim、fzf-lua、markview.nvim、grug-far.nvim、neo-tree.nvim、nui.nvim、plenary.nvim、nvim-lspconfig、lazydev.nvim、配色插件（均带 `.git`）
- `nvim-parser/latex.so`：预编译公式 parser
- `nvim/`、`tmux/`、`shell/`：配置与 lockfile
- `lib/common.sh`：配置部署 helper
- `install.sh`：离线安装脚本
- `versions.env`、`manifest.txt`、`SHA256SUMS`

## 1. 在联网机器上下载

要求：

- Ubuntu 24.04
- 架构与目标机器一致（`x86_64` 或 `arm64`）
- 能访问 Ubuntu 软件源和 GitHub
- 构建机需要 `nodejs`、`gcc`、`libc6-dev`、`tree-sitter`（`download.sh` 会处理构建工具；目标端不需要）

```sh
cd platforms/linux/ubuntu/24.04/offline
bash download.sh
```

产物：

```text
offline/dist/                              # 可直接拷贝的目录
offline/dev_env-ubuntu-24.04-<arch>.tar.gz # 打包后的离线包
```

也可以指定输出目录，或只生成目录、不打包：

```sh
bash download.sh --output /tmp/dev_env-offline
bash download.sh --output /tmp/dev_env-offline --no-tar
```

输出目录非空且不是之前生成的 dev_env 离线包时，脚本会拒绝覆盖；确认可以清空时加 `--force`：

```sh
bash download.sh --output /tmp/dev_env-offline --force
```

`download.sh` 会递归收集完整 apt 依赖闭包，不按构建机已安装的包裁剪；目标按干净的 Ubuntu 24.04 处理。

如果在容器/CI 中以 root 运行：

```sh
bash download.sh --allow-root
```

## 2. 拷贝到离线机器

把 `dev_env-ubuntu-24.04-<arch>.tar.gz` 拷到离线 Ubuntu 24.04，然后：

```sh
tar -xzf dev_env-ubuntu-24.04-<arch>.tar.gz
cd dev_env-ubuntu-24.04-<arch>
bash install.sh
```

或直接拷贝整个 `offline/dist/` 目录，进入目录后执行：

```sh
bash install.sh
```

## 3. 验证

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

预期与联网安装一致：Neovim 0.12.3、fzf 0.74.5、tmux 3.4+、zsh 5.9、Starship 1.27.0。

## 选项

```sh
bash install.sh --skip-config   # 只装工具；不链接配置，也不修改已有 Neovim 插件/parser
bash install.sh --skip-shell    # 只跳过 shell 配置
bash install.sh --allow-root    # 仅容器/CI
```

## 配置副本

安装时会把包内的 `nvim/`、`tmux/`、`shell/` 复制到：

```text
${XDG_DATA_HOME:-$HOME/.local/share}/dev_env/config/
```

`~/.zshrc`、`~/.config/nvim`、`~/.config/tmux/tmux.conf` 等链接到这个稳定副本。
因此安装完成后可以删除解压出来的离线包目录，不会让配置变成悬空软链接。

## 注意事项

- **架构必须一致**：apt deb 和 Neovim/fzf tarball 都是架构相关的；在 arm64 上下载的包不能装到 x86_64。
- **Ubuntu 版本必须是 24.04**：deb 依赖是按 24.04 的软件源下载的。
- 离线安装用 `dpkg -i` + `dpkg --configure -a`，不执行 `apt-get update`，不会访问网络。
- 已有 `~/.config/nvim`、`~/.config/tmux/tmux.conf`、`~/.zshrc` 会先备份。
- 离线包不会安装 fzf 的 shell 集成，只安装二进制；Neovim 使用不需要 shell 集成。
- 离线包不包含 language server、Node/npm、`clangd` 或 C/C++ 编译器。离线机器上如果想要 Python/Bash/C/C++ LSP，需要另外准备这些包；否则 Neovim 仍可启动，只是对应语言的 LSP 不工作。可用 `bash nvim/scripts/check-lsp.sh` 查看缺失项。
- Ubuntu 安装器不会自动 `chsh`；需要默认 zsh 时手动执行 `chsh -s "$(command -v zsh)"`。
- 终端配色只复制到 `~/.local/share/dev_env/terminal/`，不会自动修改 GNOME Terminal/Kitty 等终端偏好。
- `download.sh` 只会在带 dev_env 标记或显式 `--force` 的输出目录里重新生成 `dist/debs/`；不要把重要文件放在这个目录。
- 离线包默认不提交到 git（见 `.gitignore`），需要时再单独传输。

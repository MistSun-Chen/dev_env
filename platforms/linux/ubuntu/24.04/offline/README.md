# Ubuntu 24.04 离线安装

适用场景：目标机器**不能联网**，但可以拷入一个离线包。

离线包包含：

- `debs/`：`ca-certificates`、`curl`、`git`、`ripgrep`、`fd-find` 及其依赖
- `nvim-linux-*.tar.gz`：Neovim 官方二进制
- `fzf-*-linux_*.tar.gz`：fzf 官方二进制
- `tree-sitter-cli-linux-*.zip`：tree-sitter CLI
- `nvim-plugins/`：lazy.nvim 根目录，含 lazy.nvim、fzf-lua、markview.nvim、grug-far.nvim、neo-tree.nvim、nui.nvim、plenary.nvim、配色插件（均带 `.git`）
- `nvim-parser/latex.so`：预编译公式 parser
- `nvim/`：Neovim 配置与 lockfile
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

`download.sh` 会递归收集 apt 依赖，并排除当前系统已安装的包；目标按干净的 Ubuntu 24.04 处理。

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
rg --version | head -1
fd --version
fzf --version
git --version
tree-sitter --version
```

预期与联网安装一致：Neovim 0.12.3、fzf 0.74.5。

## 选项

```sh
bash install.sh --skip-config   # 只装工具，不接管 Neovim 配置
bash install.sh --allow-root    # 仅容器/CI
```

## 注意事项

- **架构必须一致**：apt deb 和 Neovim/fzf tarball 都是架构相关的；在 arm64 上下载的包不能装到 x86_64。
- **Ubuntu 版本必须是 24.04**：deb 依赖是按 24.04 的软件源下载的。
- 离线安装用 `dpkg -i` + `dpkg --configure -a`，不执行 `apt-get update`，不会访问网络。
- 已有 `~/.config/nvim` 会先备份为 `~/.config/nvim.bak.YYYYMMDD-HHMMSS`。
- 离线包不会安装 fzf 的 shell 集成，只安装二进制；Neovim 使用不需要 shell 集成。
- `download.sh` 会清空并重新生成 `dist/debs/`；不要把重要文件放在这个目录。
- 离线包默认不提交到 git（见 `.gitignore`），需要时再单独传输。

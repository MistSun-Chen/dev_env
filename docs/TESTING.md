# 测试与验证

本文说明如何验证 `dev_env` 的安装脚本。README 只保留入口和概览。

## 1. 测试原则

- 测试使用临时目录/临时容器，不把离线包提交到仓库。
- Ubuntu 测试在 Docker 中运行；macOS 测试在本机运行，并使用临时 `XDG_CONFIG_HOME`。
- 测试脚本使用 `--skip-config` 或临时配置目录，避免覆盖真实 `~/.config/nvim`。
- 离线测试必须在 `--network none` 的容器中运行，确认安装过程不依赖网络。

## 2. Ubuntu 24.04（Docker）

### 2.1 前置条件

- Docker 已安装，daemon 正在运行
- 能访问 Ubuntu 软件源和 GitHub

Docker Desktop 需要走宿主机代理时：

```sh
export DOCKER_PROXY=http://host.docker.internal:7897
```

Linux 上如果 Docker 不支持 `host.docker.internal`，改用宿主机在 Docker bridge 上的地址，或让容器直接联网。

### 2.2 联网安装测试

```sh
bash tests/ubuntu-24.04-online.sh
```

脚本会：

1. 启动 `ubuntu:24.04` 容器；
2. 把仓库只读挂载到 `/work`；
3. 执行 `install.sh --allow-root --skip-config`；
4. 检查 Neovim、rg、fd、fzf、git 版本。

### 2.3 离线安装测试

```sh
bash tests/ubuntu-24.04-offline.sh
```

脚本会：

1. 在联网容器中执行 `offline/download.sh --output /bundle --no-tar --allow-root`；
2. 把离线包生成到宿主机临时目录；
3. 启动 `--network none` 的全新 `ubuntu:24.04`；
4. 执行离线包的 `install.sh --allow-root --skip-config`；
5. 检查版本并清理临时目录。

离线包约 30–40 MB，生成和安装需要几分钟。

### 2.4 实测记录

2026-10-20 在 Apple Silicon Mac（Docker Desktop，arm64 容器）上：

- `tests/ubuntu-24.04-online.sh` 通过；
- `tests/ubuntu-24.04-offline.sh` 通过；
- 离线安装在不联网容器中完成，版本为 Neovim 0.12.3、fzf 0.74.5、ripgrep 14.1.0、fd 9.0.0。

## 3. macOS（本机）

### 3.1 联网安装测试

使用临时配置目录，避免改动真实配置：

```sh
XDG_CONFIG_HOME="$(mktemp -d)" bash platforms/macos/install.sh
```

注意：这个测试会真实安装/升级 `~/.local` 下的 Neovim/fzf，以及 Homebrew 的 `ripgrep`/`fd`/`git`（仅缺失时）。

验证：

```sh
nvim --version | head -1
fzf --version
rg --version | head -1
fd --version
git --version
```

### 3.2 离线安装测试

在临时目录生成离线包，并用临时 `HOME` 安装：

```sh
BUNDLE="$(mktemp -d)"
HOME_TMP="$(mktemp -d)"
CONFIG_TMP="$(mktemp -d)"

bash platforms/macos/offline/download.sh --output "$BUNDLE" --no-tar
HOME="$HOME_TMP" XDG_CONFIG_HOME="$CONFIG_TMP" bash "$BUNDLE/install.sh"
```

验证：

```sh
"$HOME_TMP/.local/bin/nvim" --version | head -1
"$HOME_TMP/.local/bin/fzf" --version
"$HOME_TMP/.local/bin/rg" --version | head -1
"$HOME_TMP/.local/bin/fd" --version
readlink "$CONFIG_TMP/nvim"
```

### 3.3 实测记录

2026-10-20 在 MacBook M4（macOS，arm64）上：

- 联网脚本通过；Homebrew 安装了 ripgrep 15.2.0、fd 10.5.0；fzf 0.74.5 从官方 tarball 安装；Neovim 0.12.3 已存在则跳过；
- 临时 `XDG_CONFIG_HOME` 下配置链接正确；
- 离线包约 17 MB，生成和 `shasum -a 256 -c` 校验通过；
- 临时 `HOME` 下离线安装成功，Neovim 0.12.3、fzf 0.74.5、ripgrep 15.2.0、fd 10.5.0 均可执行。

## 4. 手动验证清单

无论哪个平台，安装后检查：

```sh
nvim --version | head -1
rg --version | head -1
fd --version
fzf --version
git --version
```

配置：

```sh
nvim --headless "+lua print(vim.o.number, vim.o.relativenumber, vim.o.ignorecase, vim.o.smartcase, vim.o.mouse, vim.o.shortmess:find('I') ~= nil)" +qa
```

期望：

```text
true	true	true	true	a	true
```

交互：

- normal / insert 按方向键，出现 `Use h/l/k/j`；
- `Q` 保留 Neovim 默认行为；
- `~/.config/nvim` 指向仓库的 `nvim/`；
- 修改仓库 `nvim/init.lua` 后，新启动的 Neovim 配置生效（软链接安装）。

## 5. 测试文件

```text
tests/
├── README.md
├── ubuntu-24.04-online.sh
└── ubuntu-24.04-offline.sh
```

平台脚本和离线脚本的详细说明：

- [`../platforms/linux/ubuntu/24.04/offline/README.md`](../platforms/linux/ubuntu/24.04/offline/README.md)
- [`../platforms/macos/offline/README.md`](../platforms/macos/offline/README.md)

## 6. 新增平台时怎么测

1. 用该平台的官方最小镜像/容器（如 `ubuntu:24.04`、Windows Server Core、macOS runner）。
2. 联网测试：执行安装脚本的 `--skip-config` 或临时配置目录模式。
3. 离线测试：
   - 在联网环境生成离线包；
   - 在 `--network none` / 断网环境执行离线安装；
   - 校验版本和配置链接。
4. 把测试命令追加到本文档和 `tests/`。

## 7. 注意

- 测试容器里用 `--allow-root`，生产环境默认拒绝 root。
- 离线包不提交到 git；`offline/.gitignore` 已忽略 `dist/` 和生成的 tar.gz。
- macOS 联网测试会实际安装/升级工具，建议在确认可以修改本机环境时运行。
- 如果 Docker 拉取镜像或 apt 很慢，先配置 `DOCKER_PROXY` 或使用离线包。

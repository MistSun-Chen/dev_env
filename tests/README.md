# 测试脚本

> 完整测试说明与实测记录见 [`../docs/TESTING.md`](../docs/TESTING.md)。本文件只保留脚本级说明。

这里放可重复执行的安装测试。当前覆盖 Ubuntu 24.04：

- `ubuntu-24.04-online.sh`：在 Docker 里跑联网安装，并验证 Neovim、tmux 3.8、zsh、Starship、插件、latex parser、2clip、mermaid-ascii 和 pyright/bashls
- `ubuntu-24.04-offline.sh`：先在 Docker 里生成离线包（含自包含 tmux 3.8 和 mermaid-ascii），再在 `--network none` 的容器里离线安装；检查稳定配置副本，并验证 `--skip-config` 不删除已有插件/parser
- `nvim-plugins-smoke.sh`：在本机临时 XDG 目录中安装 lazy.nvim 插件、检查配色、Markdown 目录和 latex parser
- `nvim-mermaid-ascii-smoke.sh`：用最小 init 验证 Mermaid ASCII 的 extmark、`foldmethod=expr`、`foldlevel=0` 和宽图提示（只有宽图出现一次）；缺少 `mermaid-ascii` 时跳过
- `tmux-config-smoke.sh`：用独立 socket 验证 tmux 选项和键位，不碰默认 server
- `shell-config-smoke.sh`：临时 HOME/ZDOTDIR 验证 zsh 配置、alias、local override、Starship 和 2clip 的 OSC 52 输出
- `theme-assets-smoke.sh`：验证 iTerm2/Terminal/Linux/VS Code 配色文件和调色板
- `macos-offline-installer-safety-smoke.sh`：用合成离线包验证稳定配置副本和 `--skip-config` 不删除插件/parser（无需网络）
- `macos-tmux-build-smoke.sh`：macOS 慢测试，构建 3.8、检查自包含 tmux 二进制，并用构建结果运行 tmux 配置 smoke（需 `DEV_ENV_RUN_SLOW_TESTS=1`）

## 前置条件

- 已安装 Docker，并且 daemon 正在运行
- 能访问 Ubuntu 软件源和 GitHub
- 需要代理时设置 `DOCKER_PROXY`；如果 apt 需要绕过代理，可再设置 `DOCKER_NO_PROXY=ports.ubuntu.com,archive.ubuntu.com,security.ubuntu.com`
- 需要换 apt 镜像时设置 `DOCKER_APT_MIRROR`（x86_64 用 `.../ubuntu`，arm64 用 `.../ubuntu-ports`）；HTTPS 镜像要求基础镜像已有 `ca-certificates`，可用 `DOCKER_IMAGE`/`DOCKER_BUILDER_IMAGE` 指定带 CA 的镜像

如果 Docker 容器需要走宿主机代理，设置 `DOCKER_PROXY`：

```sh
export DOCKER_PROXY=http://host.docker.internal:7897
```

> `host.docker.internal` 是 Docker Desktop（macOS/Windows）访问宿主机的地址。
> Linux 上如果 Docker 不支持这个域名，可以改用宿主机在 Docker bridge 上的地址，或让容器直接联网。

## Docker Desktop / 网络排查

### 容器启动挂起

如果 `docker run` 停在 `Created`，或 `docker start` 超时，先重启 Docker Desktop；仍失败时可临时直连 Docker Desktop 的 VM socket：

```sh
export DOCKER_HOST="unix://$HOME/Library/Containers/com.docker.docker/Data/docker.raw.sock"
```

这是本机绕过手段，不是测试默认配置。raw socket 可能不共享 `/tmp`、`/var/folders`；离线测试已把 bundle 放在 `${XDG_CACHE_HOME:-$HOME/.cache}`。

### amd64 与 CA

```sh
export DOCKER_DEFAULT_PLATFORM=linux/amd64
export DOCKER_APT_MIRROR=https://mirrors.aliyun.com/ubuntu
# 仅当镜像已安装 ca-certificates 时设置；默认仍是 ubuntu:24.04
export DOCKER_IMAGE=dev-env-ubuntu:24.04-ca
export DOCKER_BUILDER_IMAGE=dev-env-ubuntu:24.04-ca
```

- 在线测试使用 `DOCKER_IMAGE`；
- 离线测试的构建容器使用 `DOCKER_BUILDER_IMAGE`，目标容器使用 `DOCKER_IMAGE`（默认干净 `ubuntu:24.04`）；
- 不要在仓库或 CI 中通过 `Acquire::https::Verify-Peer "false"` 绕过 CA；
- 更完整的排查说明见 [`../docs/TESTING.md`](../docs/TESTING.md) 的“Docker Desktop 与网络排查”。

## 联网安装测试

```sh
bash tests/ubuntu-24.04-online.sh
```

它会：

1. 启动 `ubuntu:24.04` 容器；
2. 挂载仓库到 `/work`（只读）；
3. 在容器内把 `/work` 复制到可写的 `/tmp/work`；
4. 执行 `install.sh --allow-root`，安装工具、插件和 parser；
5. 检查 Neovim、tmux、zsh、Starship、rg、fd、fzf、git、tree-sitter 版本并加载配置；
6. 检查 `~/.zshrc`、`~/.config/tmux/tmux.conf` 链接和 `~/.zshrc.local` 权限。

容器内的安装只写入容器自己的 `/root/.local`，测试结束后随容器删除。

## 离线安装测试

```sh
bash tests/ubuntu-24.04-offline.sh
```

它会：

1. 在联网容器里执行 `offline/download.sh --output /bundle --no-tar --allow-root`；
2. 生成离线包到宿主机临时目录；
3. 启动一个 `--network none` 的全新 `ubuntu:24.04` 容器；
4. 执行离线包的 `install.sh --allow-root`，安装插件和 parser；
5. 检查版本、配置链接、tmux 私有 socket，并删除临时离线包。

离线包体积约 140–150 MB（含插件、parser、tmux、Starship 和字体），生成和安装都需要几分钟；脚本不会把离线包提交到仓库。

## 本机冒烟测试

```sh
bash tests/tmux-config-smoke.sh
bash tests/shell-config-smoke.sh
bash tests/theme-assets-smoke.sh
DEV_ENV_RUN_SLOW_TESTS=1 bash tests/macos-tmux-build-smoke.sh
```

前三个使用临时 HOME/XDG 或私有 tmux socket；最后一个会下载并构建 tmux，耗时较长。

## 说明

- 测试容器使用 `--allow-root`，因为容器默认是 root；生产环境脚本默认拒绝 root。
- 测试在容器内使用独立路径，不写真实 `~/.config/nvim`、`~/.config/tmux`、`~/.zshrc`；配置、插件和 parser 都会在测试中实际加载。
- tmux 测试只使用唯一 socket，不执行 `tmux kill-*` 或触碰默认 server。
- 如果在 CI 中运行，建议固定 Ubuntu 镜像 digest，或至少固定 `ubuntu:24.04` 标签。

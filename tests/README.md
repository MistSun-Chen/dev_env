# 测试脚本

> 完整测试说明与实测记录见 [`../docs/TESTING.md`](../docs/TESTING.md)。本文件只保留脚本级说明。

这里放可重复执行的安装测试。当前覆盖 Ubuntu 24.04：

- `ubuntu-24.04-online.sh`：在 Docker 里跑联网安装
- `ubuntu-24.04-offline.sh`：先在 Docker 里生成离线包，再在 `--network none` 的容器里离线安装

## 前置条件

- 已安装 Docker，并且 daemon 正在运行
- 能访问 Ubuntu 软件源和 GitHub

如果 Docker 容器需要走宿主机代理，设置 `DOCKER_PROXY`：

```sh
export DOCKER_PROXY=http://host.docker.internal:7897
```

> `host.docker.internal` 是 Docker Desktop（macOS/Windows）访问宿主机的地址。
> Linux 上如果 Docker 不支持这个域名，可以改用宿主机在 Docker bridge 上的地址，或让容器直接联网。

## 联网安装测试

```sh
bash tests/ubuntu-24.04-online.sh
```

它会：

1. 启动 `ubuntu:24.04` 容器；
2. 挂载仓库到 `/work`（只读）；
3. 执行 `platforms/linux/ubuntu/24.04/install.sh --allow-root --skip-config`；
4. 检查 Neovim、rg、fd、fzf、git 版本。

容器内的安装只写入容器自己的 `/root/.local`，测试结束后随容器删除。

## 离线安装测试

```sh
bash tests/ubuntu-24.04-offline.sh
```

它会：

1. 在联网容器里执行 `offline/download.sh --output /bundle --no-tar --allow-root`；
2. 生成离线包到宿主机临时目录；
3. 启动一个 `--network none` 的全新 `ubuntu:24.04` 容器；
4. 执行离线包的 `install.sh --allow-root --skip-config`；
5. 检查版本并删除临时离线包。

离线包体积约 40 MB，生成和安装都需要一点时间；脚本不会把离线包提交到仓库。

## 说明

- 测试容器使用 `--allow-root`，因为容器默认是 root；生产环境脚本默认拒绝 root。
- 测试使用 `--skip-config`，避免在容器里写 `~/.config/nvim`；配置本身由离线包完整性校验和后续手动验证覆盖。
- 如果在 CI 中运行，建议固定 Ubuntu 镜像 digest，或至少固定 `ubuntu:24.04` 标签。

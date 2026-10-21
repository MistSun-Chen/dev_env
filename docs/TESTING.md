# 测试与验证

本文说明如何验证 `dev_env` 的安装脚本。README 只保留入口和概览。

## 1. 测试原则

- 测试使用临时目录/临时容器，不把离线包提交到仓库。
- Ubuntu 测试在 Docker 中运行；macOS 测试在本机运行，并使用临时 `XDG_CONFIG_HOME`。
- 测试脚本使用临时配置目录或容器内可写副本，避免覆盖真实 `~/.config/nvim`。
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
2. 把仓库只读挂载到 `/work`，在容器内复制到可写的 `/tmp/work`；
3. 执行 `install.sh --allow-root`，安装工具、插件和 parser；
4. 检查 Neovim、rg、fd、fzf、git、mermaid-ascii、tree-sitter 版本，并加载配置。

### 2.3 离线安装测试

```sh
bash tests/ubuntu-24.04-offline.sh
```

脚本会：

1. 在联网容器中执行 `offline/download.sh --output /bundle --no-tar --allow-root`；
2. 把离线包生成到宿主机临时目录；
3. 启动 `--network none` 的全新 `ubuntu:24.04`；
4. 执行离线包的 `install.sh --allow-root`，安装插件和预编译 parser；
5. 检查版本、插件加载并清理临时目录。

离线包约 80 MB（含 apt deb、插件和 parser），生成和安装需要几分钟。

### 2.4 实测记录

2026-10-20 在 Apple Silicon Mac（Docker Desktop，arm64 容器）上，使用当时的 `vim.pack` 方案：

- `tests/ubuntu-24.04-online.sh` 通过；安装 Neovim 0.12.3、fzf 0.74.5、ripgrep 14.1.0、fd 9.0.0、mermaid-ascii 1.6.1、tree-sitter 0.27.1，并安装 fzf-lua/markview、编译 `latex.so`；
- `tests/ubuntu-24.04-offline.sh` 通过；离线包约 82 MB，在 `--network none` 容器中安装成功，插件和 parser 可加载。

2026-10-21 迁移到 lazy.nvim 后：

- 本机 `tests/nvim-plugins-smoke.sh` 通过，包含 lazy.nvim commit 固定、`lazy-lock.json`、插件加载、latex parser 和 Mermaid extmark 检查；
- 2026-10-21 添加 Markdown 目录和配色后，真实环境验证通过：默认 `catppuccin-mocha`，Mocha/Macchiato/Frappe/Latte 四个变体可用，`<leader>mt` 可提取标题；
- 添加配色后的隔离 smoke test 再次运行时，在临时环境 clone lazy.nvim 阶段遇到 GitHub 443 连接失败，未完成；这是网络问题，不是配置错误；
- `nvim/scripts/stage-plugins.sh` 在临时目录生成 lazy.nvim 根目录、lockfile 和 `latex.so`，并用 `--check` 在无插件安装步骤下加载成功；
- `tests/ubuntu-24.04-offline.sh` 本次未完成：联网容器在 `apt-get update` 拉取 Ubuntu `universe` 索引时连接失败（`Connection failed`），尚未进入插件 staging 阶段，属于网络问题，待网络恢复后重跑。

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

2026-10-20 在 MacBook M4（macOS，arm64）上，使用当时的 `vim.pack` 方案：

- 联网脚本通过；Homebrew 安装了 ripgrep 15.2.0、fd 10.5.0；fzf 0.74.5 从官方 tarball 安装；Neovim 0.12.3 已存在则跳过；
- 联网脚本安装了 mermaid-ascii 1.6.1、tree-sitter 0.27.1，安装了 fzf-lua/markview，并编译 `latex.so`；
- 临时 `XDG_CONFIG_HOME` 下配置链接正确；
- 离线包约 61 MB，生成和 `shasum -a 256 -c` 校验通过；
- 临时 `HOME` 下离线安装成功，Neovim 0.12.3、fzf 0.74.5、ripgrep 15.2.0、fd 10.5.0、mermaid-ascii、tree-sitter 均可执行；
- 离线安装后的 Neovim 在临时环境中成功加载 markview、Mermaid extmark 和 `latex` parser。

2026-10-21 迁移到 lazy.nvim 后，本机隔离测试已在临时 `XDG_CONFIG_HOME` / `XDG_DATA_HOME` 中验证 lazy.nvim、fzf-lua、markview 和 `latex` parser 可加载；Docker 离线测试受上述 Ubuntu 源网络问题阻塞。

## 4. Neovim 插件与预览测试

### 4.1 临时环境安装插件

不要覆盖真实 `~/.config/nvim`：

```sh
TMP_CONFIG="$(mktemp -d)"
TMP_DATA="$(mktemp -d)"
XDG_CONFIG_HOME="$TMP_CONFIG" XDG_DATA_HOME="$TMP_DATA" \
  bash nvim/scripts/install-plugins.sh
XDG_CONFIG_HOME="$TMP_CONFIG" XDG_DATA_HOME="$TMP_DATA" \
  bash nvim/scripts/install-plugins.sh --check
```

### 4.2 检查插件和 parser

```sh
TMP_CONFIG="$(mktemp -d)"
TMP_DATA="$(mktemp -d)"
XDG_CONFIG_HOME="$TMP_CONFIG" XDG_DATA_HOME="$TMP_DATA" \
  nvim --headless "+lua assert(pcall(require,'lazy')); assert(pcall(require,'fzf-lua')); assert(pcall(require,'markview')); assert(vim.treesitter.language.add('latex')); assert(vim.g.colors_name == 'catppuccin-mocha'); local colors=vim.fn.getcompletion('', 'color'); for _,n in ipairs({'catppuccin-mocha','catppuccin-macchiato','catppuccin-frappe','catppuccin-latte'}) do assert(vim.tbl_contains(colors,n), n) end; assert(require('config.markdown_toc').get_headings(0))" +qa
```

### 4.3 Markdown + Mermaid 冒烟测试

创建包含 `$E=mc^2$` 和 ```` ```mermaid graph LR ... ``` ```` 的临时 Markdown，执行：

```vim
:Markview Enable
:MermaidRender
```

用 Lua 检查 `dev_env_mermaid` namespace 有 `virt_lines` extmark。注意：`nvim --headless` 只用于测试，不能直接“看”预览；实际查看需要在普通终端启动 Neovim。

### 4.4 离线插件加载

在离线包的临时 `HOME`/`XDG_CONFIG_HOME`/`XDG_DATA_HOME` 下运行：

```sh
bash nvim/scripts/install-plugins.sh --check
```

确认 `lazy-lock.json`、`lazy/{lazy.nvim,fzf-lua,markview.nvim,配色插件}`、`site/parser/latex.so` 都存在，并且启动过程不访问网络。

## 5. 手动验证清单

无论哪个平台，安装后检查：

```sh
nvim --version | head -1
rg --version | head -1
fd --version
fzf --version
git --version
mermaid-ascii --help >/dev/null && echo mermaid-ok
tree-sitter --version
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

## 6. 测试文件

```text
tests/
├── README.md
├── ubuntu-24.04-online.sh
├── ubuntu-24.04-offline.sh
└── nvim-plugins-smoke.sh
```

平台脚本和离线脚本的详细说明：

- [`../platforms/linux/ubuntu/24.04/offline/README.md`](../platforms/linux/ubuntu/24.04/offline/README.md)
- [`../platforms/macos/offline/README.md`](../platforms/macos/offline/README.md)

## 7. 新增平台时怎么测

1. 用该平台的官方最小镜像/容器（如 `ubuntu:24.04`、Windows Server Core、macOS runner）。
2. 联网测试：执行安装脚本的 `--skip-config` 或临时配置目录模式。
3. 离线测试：
   - 在联网环境生成离线包；
   - 在 `--network none` / 断网环境执行离线安装；
   - 校验版本和配置链接。
4. 把测试命令追加到本文档和 `tests/`。

## 8. 注意

- 测试容器里用 `--allow-root`，生产环境默认拒绝 root。
- 离线包不提交到 git；`offline/.gitignore` 已忽略 `dist/` 和生成的 tar.gz。
- macOS 联网测试会实际安装/升级工具，建议在确认可以修改本机环境时运行。
- 如果 Docker 拉取镜像或 apt 很慢，先配置 `DOCKER_PROXY` 或使用离线包。

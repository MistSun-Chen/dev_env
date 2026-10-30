# 测试与验证

本文说明如何验证 `dev_env` 的安装脚本。README 只保留入口和概览。

## 1. 测试原则

- 测试使用临时目录/临时容器，不把离线包提交到仓库。
- Ubuntu 测试在 Docker 中运行；macOS 测试在本机运行，并使用临时 `XDG_CONFIG_HOME`。
- 测试脚本使用临时配置目录或容器内可写副本，避免覆盖真实 `~/.config/nvim`、`~/.config/tmux`、`~/.zshrc`。
- tmux 测试使用唯一 socket；结束时通过 `exit`/`C-c` 关闭测试 session，不对默认 server 执行 `kill-*`。
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

如果代理只监听 `127.0.0.1`（例如某些 Clash 配置），容器内的 `host.docker.internal:7897` 会连接失败；此时让容器直接联网，或在代理里开启允许局域网/绑定可用地址。不要把这种代理不可达误判为安装脚本失败。

### 2.2 联网安装测试

```sh
bash tests/ubuntu-24.04-online.sh
```

脚本会：

1. 启动 `ubuntu:24.04` 容器；
2. 把仓库只读挂载到 `/work`，在容器内复制到可写的 `/tmp/work`；
3. 执行 `install.sh --allow-root`，安装工具、插件和 parser；
4. 检查 Neovim、tmux、zsh、Starship、rg、fd、fzf、git、tree-sitter 版本，并加载配置；
5. 检查 `~/.zshrc`、`~/.config/tmux/tmux.conf` 链接、`~/.zshrc.local` 权限，以及 tmux 私有 socket 键位。

### 2.3 离线安装测试

```sh
bash tests/ubuntu-24.04-offline.sh
```

脚本会：

1. 在联网容器中执行 `offline/download.sh --output /bundle --no-tar --allow-root`；
2. 把离线包生成到宿主机临时目录；
3. 启动 `--network none` 的全新 `ubuntu:24.04`；
4. 执行离线包的 `install.sh --allow-root`，安装插件和预编译 parser；
5. 检查版本、稳定配置副本（`~/.local/share/dev_env/config`）、配置链接、tmux 私有 socket；
6. 再执行一次 `--skip-config`，确认已有 Neovim 插件和 `latex.so` 未被删除；
7. 清理临时目录。

离线包约 140–150 MB（含 apt deb、插件、parser、tmux 3.8 二进制、Starship 和字体），生成和安装需要几分钟。

### 2.4 实测记录

2026-10-20 在 Apple Silicon Mac（Docker Desktop，arm64 容器）上，使用当时的 `vim.pack` 方案：

- `tests/ubuntu-24.04-online.sh` 通过；安装 Neovim 0.12.3、fzf 0.74.5、ripgrep 14.1.0、fd 9.0.0、tree-sitter 0.27.1，并安装 fzf-lua/markview/grug-far、编译 `latex.so`；
- `tests/ubuntu-24.04-offline.sh` 通过；离线包约 82 MB，在 `--network none` 容器中安装成功，插件和 parser 可加载。

2026-10-21 迁移到 lazy.nvim 后：

- 本机 `tests/nvim-plugins-smoke.sh` 通过，包含 lazy.nvim commit 固定、`lazy-lock.json`、插件加载、latex parser、配色和 Markdown 目录检查；
- 2026-10-21 添加 Markdown 目录和配色后，真实环境验证通过：默认 `catppuccin-mocha`，Mocha/Macchiato/Frappe/Latte 四个变体可用，`<leader>mt` 可提取标题；
- 添加配色后的隔离 smoke test 再次运行时，在临时环境 clone lazy.nvim 阶段遇到 GitHub 443 连接失败，未完成；这是网络问题，不是配置错误；
- `nvim/scripts/stage-plugins.sh` 在临时目录生成 lazy.nvim 根目录、lockfile 和 `latex.so`，并用 `--check` 在无插件安装步骤下加载成功；
- `tests/ubuntu-24.04-offline.sh` 本次未完成：联网容器在 `apt-get update` 拉取 Ubuntu `universe` 索引时连接失败（`Connection failed`），尚未进入插件 staging 阶段，属于网络问题，待网络恢复后重跑。

## 3. macOS（本机）

### 3.1 联网安装测试

使用临时 HOME 和配置目录，避免改动真实配置：

```sh
TMP_HOME="$(mktemp -d)"
TMP_CONFIG="$(mktemp -d)"
HOME="$TMP_HOME" XDG_CONFIG_HOME="$TMP_CONFIG" bash platforms/macos/install.sh
```

注意：这个测试仍会通过 Homebrew 安装/升级 `ripgrep`/`fd`/`git`/`node`（仅缺失时），并默认构建 tmux 3.8 到临时 HOME；不会改写真实 `~/.zshrc`、`~/.config`、`~/Library/Fonts` 或 `~/.local`。

验证：

```sh
nvim --version | head -1
tmux -V
zsh --version
starship --version
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
"$HOME_TMP/.local/bin/tmux" -V
zsh --version
"$HOME_TMP/.local/bin/starship" --version
"$HOME_TMP/.local/bin/fzf" --version
"$HOME_TMP/.local/bin/rg" --version | head -1
"$HOME_TMP/.local/bin/fd" --version
readlink "$CONFIG_TMP/nvim"
readlink "$CONFIG_TMP/tmux/tmux.conf"
readlink "$HOME_TMP/.zshrc"

# 配置链接应指向稳定副本，而不是临时解压目录。
# macOS 的 /var 是 /private/var 的软链接，比较前先取物理路径。
CONFIG_ROOT_REAL="$(cd "$HOME_TMP/.local/share/dev_env/config" && pwd -P)"
test -f "$CONFIG_ROOT_REAL/nvim/init.lua"
case "$(readlink "$CONFIG_TMP/nvim")" in
  "$CONFIG_ROOT_REAL/"*) ;;
  *) echo "nvim config 未指向稳定副本" >&2; exit 1 ;;
esac
```

### 3.3 实测记录

2026-10-20 在 MacBook M4（macOS，arm64）上，使用当时的 `vim.pack` 方案：

- 联网脚本通过；Homebrew 安装了 ripgrep 15.2.0、fd 10.5.0；fzf 0.74.5 从官方 tarball 安装；Neovim 0.12.3 已存在则跳过；
- 联网脚本安装了 tree-sitter 0.27.1，安装了 fzf-lua/markview/grug-far，并编译 `latex.so`；
- 临时 `XDG_CONFIG_HOME` 下配置链接正确；
- 离线包约 61 MB，生成和 `shasum -a 256 -c` 校验通过；
- 临时 `HOME` 下离线安装成功，Neovim 0.12.3、fzf 0.74.5、ripgrep 15.2.0、fd 10.5.0、tree-sitter 均可执行；
- 离线安装后的 Neovim 在临时环境中成功加载 markview 和 `latex` parser。

2026-10-21 迁移到 lazy.nvim 后，本机隔离测试已在临时 `XDG_CONFIG_HOME` / `XDG_DATA_HOME` 中验证 lazy.nvim、fzf-lua、markview 和 `latex` parser 可加载；Docker 离线测试受上述 Ubuntu 源网络问题阻塞。

2026-10-27 添加 tmux + zsh/Starship + 主题层：

- `tests/tmux-config-smoke.sh` 通过：私有 socket、`C-b` 前缀、hjkl/HJKL、滚动入口、状态栏配色；
- `tests/shell-config-smoke.sh` 通过：临时 HOME、`.zshrc` 软链接、`~/.zshrc.local` 权限 600、alias、PATH；
- `tests/theme-assets-smoke.sh` 通过：iTerm2/Terminal/Linux/VS Code 配色和调色板；
- `platforms/macos/scripts/build-tmux.sh` 成功构建 tmux 3.8；`otool -L` 只显示系统库；
- `tests/macos-tmux-build-smoke.sh`（`DEV_ENV_RUN_SLOW_TESTS=1`）通过；
- macOS 临时 HOME 下 `install.sh --skip-config` 成功安装 Starship 和 Meslo 字体；Neovim/fzf 因测试 PATH 命中宿主机已有安装而跳过，属于测试环境现象；
- macOS 临时 HOME 下离线包安装通过：tmux 3.8、zsh 5.9、Starship 1.27.0、字体、配置软链接和终端配色资源均正常；离线包约 104 MB；
- Ubuntu Docker 联网测试通过：tmux 3.4、zsh 5.9、Starship 1.27.0，`~/.zshrc`/tmux 配置软链接和 `~/.zshrc.local` 权限正常；
- Ubuntu Docker 离线测试通过（`--network none`）：离线包约 127 MB，tmux/zsh/Starship/字体/配置均可用。

2026-10-29 验收调整：

- tmux 暂时移除自定义选择/复制键、`pbcopy`/OSC52 和 `set-clipboard`，只保留滚动入口；复制/粘贴后续单独章节处理；
- zsh 增加 Option/Ctrl+方向键 word navigation，`tests/shell-config-smoke.sh` 增加对应 bindkey 断言；
- `tests/tmux-config-smoke.sh`、`tests/shell-config-smoke.sh`、`tests/theme-assets-smoke.sh` 均通过；
- 本机 `~/.config/nvim`、`~/.config/tmux/tmux.conf`、`~/.zshrc`、`~/.config/starship.toml` 已链接到 `dev_env`，当前 tmux server 已 reload 新配置。

2026-10-29 PR 自审修复：

- 离线包把配置复制到 `${XDG_DATA_HOME:-$HOME/.local/share}/dev_env/config/` 后再链接，删除解压目录不会产生悬空软链接；
- `--skip-config` 不再删除已有 Neovim 插件或 `latex.so`；
- `download.sh` 对非空输出目录要求 dev_env 标记或 `--force`；`build-tmux.sh` 不再删除用户通过 `--work` 指定的目录；
- Ubuntu 离线包的 apt 依赖改为完整递归闭包，不按构建机已安装包裁剪；
- tmux `C-b r` 使用 `XDG_CONFIG_HOME`；测试改为不传 `-f`，验证自定义 XDG 配置发现；
- Neovim 安装后冒烟测试改为断言核心选项和配色，并显式设置 `PATH`/`XDG_*`；
- shell smoke 使用 `mktemp` 输出文件；shellcheck 新警告已清零；
- Ubuntu 安装/离线下载的 apt 增加 `Acquire::Retries`、超时和 `Pipeline-Depth=0`，降低大包卡住后失败的概率；
- `tests/macos-tmux-build-smoke.sh` 通过；额外验证 `build-tmux.sh --work <用户目录>` 不会删除该目录中的已有文件；
- `tests/macos-offline-installer-safety-smoke.sh` 通过：合成离线包验证稳定配置副本和 `--skip-config` 保留插件/parser；
- macOS 完整离线包本次没有重跑（GitHub release 资产在当前网络不可达）；此前 2026-10-27 的完整离线安装通过，本次改动路径由 synthetic + build 测试覆盖。

2026-10-29 PR 自审后的 Ubuntu 平台验证：

- 当前网络下 `github.com` 解析到不可达 IP，默认 GitHub release 下载超时；apt 阶段本身可通过。这是外部网络问题，不是安装脚本错误；
- 为完成回归验证，使用临时测试副本把 GitHub release URL 指向 `ghproxy.net`，并让 Docker 通过宿主机可达的 TCP 代理访问 apt/git；仓库默认 URL 未改动；
- `tests/ubuntu-24.04-offline.sh` 通过：离线包约 142 MB，在 `--network none` 容器中安装成功；配置链接指向 `/root/.local/share/dev_env/config`，`--skip-config` 未删除已有插件/parser；
- `tests/ubuntu-24.04-online.sh` 使用同一镜像/代理通过：Neovim 0.12.3、tmux 3.4、zsh 5.9、Starship 1.27.0；验证了新加的核心选项/配色断言、tmux 无 `-f` 配置发现、`prefix=C-b` 和 `C-b r` 的 XDG 路径。

2026-10-30 macOS tmux 3.8 统一：

- macOS 在线安装默认改为固定 3.8 自包含源码构建，安装到 `~/.local/opt/tmux-3.8` 并链接 `~/.local/bin/tmux`；`--brew-tmux` 仍可用，但要求 Homebrew tmux >=3.8；
- 离线包继续使用同一 3.8 构建，macOS 离线安装增加 `tmux -V` 版本断言；
- 重新生成 macOS 离线包时，tmux 构建阶段通过：`tmux-bin` 为 3.8，`tmux-build-info.txt` 记录 `tmux=3.8`；Neovim 插件 clone 阶段受 GitHub SSL/速度影响未完成，因此完整离线包本次未作为通过项，离线安装断言由 synthetic 测试覆盖；
- 本机 `tmux` 客户端为 3.8，新开 server 为 3.8；已运行的旧 server 仍为 3.5a，未 kill，退出旧 session 后新 server 才会切换；
- 临时 HOME 下 `install.sh --skip-config --skip-shell` 通过：tmux 3.8、Starship 1.27.0、Meslo 字体安装成功；
- `tests/tmux-config-smoke.sh` 在 tmux 3.8 下通过；
- `tests/shell-config-smoke.sh`、`tests/theme-assets-smoke.sh`、`tests/macos-offline-installer-safety-smoke.sh` 通过；
- `tests/macos-tmux-build-smoke.sh` 通过（GitHub 直连超时时使用 Clash `127.0.0.1:7897`）：构建 3.8、`otool -L` 只显示系统库，并用构建出的二进制运行 tmux 配置 smoke；直连失败属于外部网络问题。

2026-10-30 Ubuntu tmux 3.8 统一：

- Ubuntu 在线安装不再安装 apt 的 tmux 3.4；改为源码构建 3.8 到 `~/.local/opt/tmux-3.8`，并链接 `~/.local/bin/tmux`；
- Ubuntu 离线包包含预构建 `tmux-bin` 3.8 和 `tmux-build-info.txt`；离线安装以 `manifest.txt` 的 tmux 版本为准并断言；
- apt 只保留 ncurses 运行时（`libncurses6`/`libncursesw6`/`libtinfo6`），不再安装或打包 tmux 3.4；
- `tests/ubuntu-24.04-online.sh`、`tests/ubuntu-24.04-offline.sh` 改用 `~/.local/bin/tmux` 并断言 3.8；
- 在 `ubuntu:24.04`（arm64）中构建 3.8 成功；`ldd` 只显示 `libtinfo`、`libm`、`libresolv`、`libc`，libevent/utf8proc 静态链接；
- 用构建出的 3.8 运行 `tests/tmux-config-smoke.sh` 通过；
- 在线安装的临时容器验证通过（GitHub 直连/代理不稳定，使用临时 ghproxy 测试副本；仓库 URL 未改）：`/root/.local/bin/tmux` 为 3.8，系统 `/usr/bin/tmux` 不存在；
- 离线包构建成功（约 136 MB）：`tmux-bin` 为 3.8、build-info 记录 `tmux=3.8`，`debs/` 不含 tmux 3.4，包含 `libncurses6`/`libncursesw6`/`libtinfo6`；
- 在 `--network none` 的干净 `ubuntu:24.04` 中完整离线安装通过：tmux 3.8、配置软链接和 tmux 配置 smoke 通过；`ldd` 只显示 `libtinfo`、`libm`、`libresolv`、`libc`；`--skip-config` 未删除已有插件/parser；
- Ubuntu 测试使用临时 apt 镜像和 ghproxy 测试副本，仓库默认 apt/GitHub URL 未改动；
- 本次容器为 arm64；x86_64 使用同一构建脚本，分支存在但尚未实测；
- 安装器不会自动卸载旧机器上已有的 `/usr/bin/tmux` 3.4；`~/.local/bin/tmux` 在 PATH 中优先，确认后可手动 `sudo apt remove tmux`。

2026-10-30 shell 本地配置自动化：

- 新建 `~/.zshrc.local` 时自动检测 `~/.nvm/nvm.sh` 并启用 nvm，安装后新终端可直接使用 nvm 管理的 `claude`；已有文件保持不动，只有与当前模板逐字节一致时才先备份再自动补全；
- 自动探测本机代理监听端口（`7897`/`7890`），只更新模板注释中的端口，不自动开启代理；
- `shell/zshrc` 在 `STARSHIP_CONFIG` 指向不存在文件时回退到 dev_env 配置，并重新保证 `~/.local/bin` 在 PATH 最前；
- `tests/shell-config-smoke.sh` 通过：临时 HOME + 假 nvm 验证自动启用、已有 `.zshrc.local` 不被修改、Starship 配置回退；
- 本机全新登录 shell 验证通过：`claude 2.1.308`、`nvm v22.17.1`、`STARSHIP_CONFIG` 指向 dev_env 配置、PATH 第一项为 `~/.local/bin`；
- `tests/tmux-config-smoke.sh`、`shellcheck platforms/lib/common.sh tests/shell-config-smoke.sh` 通过。

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
  nvim --headless "+lua assert(pcall(require,'lazy')); assert(pcall(require,'which-key')); assert(pcall(require,'gitsigns')); assert(pcall(require,'fzf-lua')); assert(pcall(require,'markview')); assert(pcall(require,'grug-far')); assert(pcall(require,'neo-tree')); assert(pcall(require,'lazydev')); assert(vim.lsp.config ~= nil); assert(vim.treesitter.language.add('latex')); assert(vim.g.colors_name == 'catppuccin-mocha'); local colors=vim.fn.getcompletion('', 'color'); for _,n in ipairs({'catppuccin-mocha','catppuccin-macchiato','catppuccin-frappe','catppuccin-latte'}) do assert(vim.tbl_contains(colors,n), n) end; assert(require('config.markdown_toc').get_headings(0)); assert(vim.fn.maparg('<leader>et','n') ~= ''); assert(vim.fn.maparg('<leader>er','n') == ''); assert(vim.fn.maparg('<leader>ld','n') ~= ''); assert(vim.fn.maparg('<leader>ls','n') ~= '')" +qa
```

gitsigns 的验收需要在 Git 仓库中打开一个已跟踪文件，修改一行后确认左侧出现标记；用 `]c` / `[c` 跳转，`<leader>gp` 预览，`<leader>gs` 暂存后执行 `git diff --cached` 检查。`<leader>gr` 会丢弃工作区改动，测试时不要放在真实项目上。

终端验收：在普通终端启动 Neovim，按 `<leader>tt` 应出现底部终端并进入插入模式；按 `<C-\><C-n>` 回到 normal 后按 `<leader>tt` 隐藏，再按一次应恢复到同一个 shell。`nvim --headless` 只能验证 buffer 和窗口状态，不能验证真实终端的交互显示。

### 4.3 Markdown 预览冒烟测试

创建包含 `$E=mc^2$` 的临时 Markdown，执行：

```vim
:Markview Enable
```

检查无错误，并确认 Markdown 标题/表格/代码块能正常渲染。注意：`nvim --headless` 只用于测试，不能直接“看”预览；实际查看需要在普通终端启动 Neovim。

### 4.4 LSP 手动验收

`lua-language-server`、`pyright-langserver`、`bash-language-server` 都是手动安装；`clangd` 在 macOS 上通常由 Xcode Command Line Tools 提供。未安装时 smoke test 只验证插件和配置加载。安装 server 后，分别打开 Lua、Python、Bash、C/C++ 文件，检查：

```vim
:checkhealth vim.lsp
```

- Lua 文件显示 `lua_ls`，Python 显示 `pyright`，Bash 显示 `bashls`，C/C++ 显示 `clangd`；
- `K` 显示 hover；
- `gd` 跳转定义；
- `grr` 查看引用；
- `<leader>ld` 打开诊断列表；
- Lua 输入 `vim.`、Python 输入对象成员、Bash 输入变量、C/C++ 输入对象成员时出现原生补全，`<C-y>` 接受；
- C/C++ 项目有 `compile_flags.txt` 或 `compile_commands.json` 时，系统头文件和第三方头文件的解析更准确。

Python 的 Pyright 配置启用了 `basic` 类型检查；Bash 的 shellcheck 诊断需要本机有 `shellcheck`。如果 `:checkhealth vim.lsp` 没有显示已 attach 的 client，先确认 `command -v pyright-langserver`、`command -v bash-language-server`、`command -v clangd` 有输出，再检查 buffer 的 filetype 和 LSP 日志。

在 Ubuntu 上，可以先运行只读检查：

```sh
bash nvim/scripts/check-lsp.sh
```

它会分别检查 server、Node/npm、C/C++ 编译器和 Linux 标准头文件。缺少 server 时 Neovim 仍可启动；打开对应类型文件时会提示缺什么。C/C++ 只有 `clangd` 但没有编译器时，clangd 可能 attach，但标准头文件解析会不完整。

### 4.5 离线插件加载

在离线包的临时 `HOME`/`XDG_CONFIG_HOME`/`XDG_DATA_HOME` 下运行：

```sh
bash nvim/scripts/install-plugins.sh --check
```

确认 `lazy-lock.json`、`lazy/{lazy.nvim,which-key.nvim,gitsigns.nvim,fzf-lua,markview.nvim,grug-far.nvim,neo-tree.nvim,nui.nvim,plenary.nvim,nvim-lspconfig,lazydev.nvim,配色插件}`、`site/parser/latex.so` 都存在，并且启动过程不访问网络。

### 4.6 tmux / shell / 主题

```sh
bash tests/tmux-config-smoke.sh
bash tests/shell-config-smoke.sh
bash tests/theme-assets-smoke.sh
bash tests/macos-offline-installer-safety-smoke.sh
```

- tmux 测试使用唯一 socket 和自定义 `XDG_CONFIG_HOME`（不传 `-f`），断言配置发现、`prefix=C-b`、`mouse=on`、`h/j/k/l`、`H/J/K/L`、`Tab`、`r` 的 XDG 重载路径和滚动入口 `u`；复制/粘贴配置暂不测试。
- shell 测试使用临时 `HOME`，断言 `.zshrc` 软链接、`~/.zshrc.local` 权限 600、alias、PATH 和 Starship。
- 主题测试校验 iTerm2/Terminal/Linux/VS Code 配色文件和 Catppuccin 调色板。
- `macos-offline-installer-safety-smoke.sh` 用合成离线包和临时 HOME 验证：配置链接指向稳定副本，`--skip-config` 不删除已有插件/parser；不需要网络。
- 慢测试：`DEV_ENV_RUN_SLOW_TESTS=1 bash tests/macos-tmux-build-smoke.sh`，构建 3.8、检查 `otool -L` 不含 Homebrew/构建目录，并用构建出的二进制运行 tmux 配置 smoke。

## 5. 手动验证清单

无论哪个平台，安装后检查：

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
- `~/.config/tmux/tmux.conf`、`~/.zshrc` 指向仓库；新 tmux pane 能用 `C-b h/j/k/l`；
- 新 zsh 显示 Starship prompt；`~/.zshrc.local` 中的机器配置生效。

## 6. 测试文件

```text
tests/
├── README.md
├── ubuntu-24.04-online.sh
├── ubuntu-24.04-offline.sh
├── nvim-plugins-smoke.sh
├── tmux-config-smoke.sh
├── shell-config-smoke.sh
├── theme-assets-smoke.sh
├── macos-offline-installer-safety-smoke.sh
└── macos-tmux-build-smoke.sh
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

# Shell 层：zsh + Starship

`dev_env` 的 shell 从 0 设计，不依赖 Oh My Zsh、Zinit、colorls 或 Ruby/Python
插件。目标是跨 macOS/Ubuntu 一致、离线可复现。

## 组成

| 文件 | 作用 |
|---|---|
| `zshrc` | 入口；解析自身软链接路径，按顺序加载其他文件 |
| `options.zsh` | history、PATH、编辑器、基础选项 |
| `completion.zsh` | zsh 内置补全 |
| `aliases.zsh` | 精选 alias 和 `mkcd` 等小函数 |
| `plugins.zsh` | 纯 zsh 的 autosuggestions / syntax-highlighting |
| `starship.toml` | Catppuccin Mocha Powerline prompt |
| `zshrc.local.example` | 机器相关配置模板 |
| `vendor/` | 固定版本的纯 zsh 插件源码 |
| `terminal/` | 终端配色 profile |
| `fonts/` | Nerd Font 版本和离线说明 |

加载顺序：

```text
options -> completion -> aliases -> plugins -> ~/.zshrc.local
        -> starship init -> zsh-syntax-highlighting（最后）
```

`~/.zshrc.local` 用于：

- 代理/VPN；
- 真实 API key 或其他密钥；
- nvm、uv、Docker、OpenClaw、Homebrew 等机器路径；
- 旧的 colorls/autojump 等个人 alias；
- 覆盖 `STARSHIP_CONFIG`。

这个文件不进入仓库，安装器创建时权限为 `600`，已存在时绝不覆盖。

## 安装

```sh
bash platforms/macos/install.sh
bash platforms/linux/ubuntu/24.04/install.sh
```

安装器会：

1. 备份现有 `~/.zshrc`，再链接到 `dev_env/shell/zshrc`；
2. 备份并链接 `~/.config/starship.toml`；
3. 创建 `~/.zshrc.local`（如果不存在）；
4. 安装 Starship、Nerd Font，并复制终端配色资源；
5. 不修改 `~/.zprofile`、`~/.zshenv`、`~/.profile`。

Ubuntu 不会自动 `chsh`。需要默认使用 zsh 时手动执行：

```sh
chsh -s "$(command -v zsh)"
```

未改默认 shell 时，tmux pane 仍会启动 bash；可以先在终端 profile 里把
启动命令设为 `zsh`，确认无误后再 `chsh`。

## 常用 alias

- `vim` / `vi` / `v` → `nvim`
- `ls` / `ll` / `la` / `lt`：优先 `eza`，其次 `colorls`，最后系统 `ls`
- `g`、`gs`、`ga`、`gc`、`gco`、`gd`、`gp`、`gl` 等 git 简写
- `ta`、`ts`、`tl`、`td`：tmux attach/new/list/detach
- `..`、`...`、`....`、`mkcd`、`reload`、`path`

## 主题

- Prompt：Starship Catppuccin Mocha Powerline；需要 Nerd Font。配置来自 Starship v1.27.0
  的 `catppuccin-powerline` preset（MIT）。
- 终端背景/ANSI 配色：见 [`terminal/README.md`](./terminal/README.md)。
- tmux 状态栏：见 [`../tmux/tmux.conf`](../tmux/tmux.conf)。

终端 profile 不会自动导入，因为 iTerm2/Terminal/GNOME/Kitty 等终端的导入
方式不同；安装器只复制文件并给出说明，避免覆盖现有配置。

## 测试

```sh
bash tests/shell-config-smoke.sh
bash tests/theme-assets-smoke.sh
```

测试使用临时 `HOME`/`ZDOTDIR`，不会读取或修改真实的 `~/.zshrc`。

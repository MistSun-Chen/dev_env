# tmux 配置

`dev_env` 的 tmux 配置从 0 设计，不依赖 TPM 或任何插件，目标兼容 tmux 3.4+。

## 安装位置

`platforms/*/install.sh` 会把 `~/.config/tmux/tmux.conf` 链接到本文件。
如果存在旧的 `~/.tmux.conf`，安装器会先备份并移走它，避免它覆盖 XDG 配置。

本地覆盖写入 `~/.tmux.local.conf`（不存在时静默跳过），示例见
[`local.conf.example`](./local.conf.example)。

## 键位

前缀保持 `C-b`。

| 键位 | 功能 |
|---|---|
| `C-b h/j/k/l` | 焦点移动到左/下/上/右 pane |
| `C-b H/J/K/L` | 分割线向左/下/上/右移动 5 格 |
| `C-b z` | 当前 pane 最大化/还原 |
| `C-b Tab` | 上一个 window |
| `C-b C-l` | 上一个 client（替代默认的 `L`） |
| `C-b |` / `C-b -` | 水平/垂直 split，继承当前目录 |
| `C-b c` | 新 window，继承当前目录 |
| `C-b r` | 重载配置 |
| `C-b R` | 刷新 client（保留 tmux 原来的 `r` 功能） |
| `C-b u` | 进入 copy-mode 并向上翻一页（仅滚动） |
| `C-b [` | 进入 copy-mode（仅滚动） |
| `C-b x` | 关闭当前 pane（tmux 默认，会确认） |
| `C-b d` | detach |

`C-b l` 原先是 `last-window`，现在被 pane 导航占用；last-window 改到
`C-b Tab`。`C-b -` 原先的 `delete-buffer` 被 split 占用；需要时用
`C-b =` 选择 buffer。

## 没有 PageUp/PageDown 键

不需要给不存在的键做映射，按动作记：

| 场景 | 操作 |
|---|---|
| tmux 回滚 | `C-b [` 进入 copy-mode；`C-u`/`C-d` 半页，`C-b`/`C-f` 整页，`g`/`G` 顶部/底部 |
| tmux 快速上翻 | `C-b u` |
| 鼠标 | 滚轮/触控板直接滚动；`mouse on` 已开启 |
| 选择/复制 | 本阶段不配置，后续单独章节处理 |
| Neovim | `C-u`/`C-d`、`C-f`、`gg`/`G`；tmux 里不要依赖 `C-b` 翻页（会被 prefix 截获） |
| shell 历史 | `C-p`/`C-n`、`C-r` |

复制/粘贴暂不纳入本阶段配置：选择/复制快捷键已暂时移除，没有 `pbcopy`/OSC52
集成，也不设置 `set-clipboard`。当前只保留 copy-mode 的滚动入口；
后续会单独设计复制、粘贴、系统剪贴板和远程场景。

## 主题

状态栏、边框和消息使用 Catppuccin Mocha 配色，不依赖 Nerd Font。
终端窗口的背景/ANSI 配色见 [`../shell/terminal/`](../shell/terminal/)。

## 安装

联网：

```sh
bash platforms/macos/install.sh
bash platforms/linux/ubuntu/24.04/install.sh
```

macOS 默认使用 Homebrew 的 tmux；想固定 3.8 自包含版本时：

```sh
bash platforms/macos/install.sh --pinned-tmux
```

离线安装包会带 macOS 自包含 tmux 二进制；Ubuntu 使用 `tmux` 的 `.deb`。

安装器不会 kill 正在运行的 tmux server。链接新配置后，执行：

```sh
tmux source-file "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
```

或者在 tmux 里按 `C-b r`；它会按 `XDG_CONFIG_HOME` 找到配置。

或者新开一个 tmux server/session 让配置生效。

## 测试

```sh
bash tests/tmux-config-smoke.sh
```

测试使用唯一 socket 和自定义 `XDG_CONFIG_HOME`（不传 `-f`），断言配置发现、
选项、键位和 `C-b r` 的重载路径；结束测试时通过 `exit`/`C-c` 关闭测试
session，不触碰默认 tmux server，也不执行 `tmux kill-*`。

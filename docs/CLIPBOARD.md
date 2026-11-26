# 剪贴板与终端支持

本文记录 `dev_env` 的剪贴板策略、支持的终端，以及以后替换终端时需要满足的条件。

## 1. 策略

`dev_env` 的远程剪贴板统一使用 **OSC 52**：

- SSH/远程 Linux：无条件使用 OSC 52，不依赖 `xclip`/X11/Wayland；
- 本地 macOS：继续使用 `pbcopy`/`pbpaste`；
- 本地 Linux GUI：X11 有 `xclip`/`xsel`，或 Wayland 有 `wl-copy` + `wl-paste` 时优先原生 provider，否则回退 OSC 52。

以上三条是 Neovim 的 provider 策略；shell 的 `2clip` 例外，始终使用 OSC 52。

`nvim/init.lua` 通过 `SSH_TTY` / `SSH_CONNECTION` 判断是否处于 SSH 会话；SSH 到 Linux
时设置 `vim.g.clipboard = 'osc52'`。这不影响普通 `y/d/c/p`：只有 `<leader>y` / `<leader>p`
显式使用 `+` 寄存器，`clipboard=unnamedplus` 始终关闭。

Shell 统一使用 `2clip`（安装到 `~/.local/bin/2clip`）：它总是把内容通过 OSC 52
写到最外层终端，本地 macOS 和 SSH 会话相同。Neovim 的策略不受影响：本地 macOS
仍用 `pbcopy`/`pbpaste`，SSH/远程 Linux 用 OSC 52。

## 2. 支持的终端

OSC 52 由**最外层终端**解释；SSH 只负责转发字节。终端必须支持 OSC 52 写（复制）。

| 终端 | OSC 52 写（复制） | 说明 |
|---|---|---|
| Windows Terminal | ✅ | 默认开启；`compatibility.allowOSC52` 默认 `true`；只支持写，不支持读 |
| WezTerm | ✅ | 跨平台，OSC 52 支持较完整 |
| Alacritty | ✅ | 写默认可用；0.13+ 读默认关闭，需要 `terminal.osc52` |
| iTerm2（macOS） | ✅ | 需要允许应用访问剪贴板；你本机已开启 |
| Kitty | ✅ | 可能需要 `clipboard_control` 允许写 |
| Ghostty | ✅ | 支持 OSC 52 |
| foot（Linux） | ✅ | 支持 OSC 52 |
| MobaXterm | ❌ | 自带终端不实现 OSC 52；X11/xclip 是另一条路，不属于 dev_env 的 SSH 方案 |
| PuTTY | ❌ | 官方未实现 OSC 52 |
| macOS Terminal.app | ❌ | 不支持 OSC 52 |
| GNOME Terminal | ❌ | 不支持 OSC 52 |

## 3. 替换终端时的要求

如果以后更换终端，至少满足：

1. **支持 OSC 52 写**：能解析 `ESC ] 52 ; c ; <base64> BEL/ST` 并写入系统剪贴板。
2. **允许剪贴板访问**：有的终端默认关闭或按策略禁用，例如 Windows Terminal 的
   `compatibility.allowOSC52`、iTerm2 的剪贴板访问设置。
3. **不拦截/过滤 OSC 序列**：SSH 客户端和终端不能把 OSC 52 丢掉。
4. **tmux 转发**：如果中间有 tmux，需要 `set -g set-clipboard on`，并让终端具备
   `clipboard`（`Ms`）能力；`dev_env/tmux/tmux.conf` 已设置 `set-clipboard on`、
   `terminal-features ',*:clipboard'`，并保持 `allow-passthrough off`。
5. **写方向足够**：复制只需要 OSC 52 写。`<leader>p` 从本地剪贴板读取需要 OSC 52 读，
   很多终端不支持或默认关闭；本地→远程粘贴请使用终端自己的粘贴快捷键。在 tmux 内，
   tmux 3.7+ 的 `get-clipboard` 默认 `buffer`，会把读请求答成 tmux 最新 buffer；旧
   server 可能不回答并让 Neovim 等待。dev_env 因此在 `$TMUX` + OSC 52 下不执行
   `<leader>p` 读取，只提示使用终端粘贴。
6. **载荷大小**：终端/tmux 对 OSC 52 有大小限制；代码片段通常没问题，超大段文本可能失败。
7. **基本终端能力**：UTF-8、256 色/true color、bracketed paste、足够 scrollback。
8. **安全边界**：OSC 52 允许远程程序写本地剪贴板，只对可信主机开启。

如果使用嵌套 tmux 或跳板机，每一层都要转发 OSC 52。

## 4. tmux 配置

`dev_env` 的 tmux 配置只做传输，不接管鼠标、不定义 copy-mode 键位：

```tmux
set -g set-clipboard on
set -g allow-passthrough off
set -as terminal-features ',*:clipboard'
```

`allow-passthrough` 只影响 DCS passthrough，不是 Neovim 原始 OSC 52 的必要条件；
dev_env 保持关闭，减少应用绕过 tmux 的路径。运行中的旧 tmux server 可以热设置，
不需要 kill：

```sh
tmux set -g set-clipboard on
tmux set -g allow-passthrough off
```

tmux 3.7+ 的 `get-clipboard` 默认是 `buffer`；如果希望应用读取时由 tmux 向本地终端
请求，可以自行评估后设置 `set -s get-clipboard request`，但这依赖终端支持 OSC 52 读，
Windows Terminal 不支持。不要依赖默认的 `buffer` 做“从本地剪贴板粘贴”。

## 5. Windows Terminal 设置

1. 用 Windows Terminal 打开 PowerShell/命令提示符，运行 `ssh user@<host>`。
2. 不需要开启 X11 forwarding；SSH 到 Linux 时会强制使用 OSC 52，无论 `$DISPLAY` 是否为空。
3. 如果复制无效，检查 Windows Terminal（1.22+）profile 的 `compatibility` 对象中是否
   保留 `"allowOSC52": true`：
   ```json
   "compatibility": { "allowOSC52": true }
   ```
   设置页里对应的剪贴板/OSC 52 兼容项，不同版本措辞可能不同。
4. Windows Terminal 的 OSC 52 是**只写**：复制到 Windows 可以；从 Windows 粘贴到远程
   Neovim 请用终端粘贴快捷键（通常 Ctrl+Shift+V）进入 insert 模式。

## 6. 快速验证

远程 shell（不经过 Neovim）：

```sh
printf '\033]52;c;%s\a' "$(printf 'DEV_ENV_OSC52_TEST' | base64)"
```

然后到本地终端粘贴（Windows Terminal 常用 Ctrl+Shift+V）。能粘贴出
`DEV_ENV_OSC52_TEST` 说明终端/SSH/tmux 链路正常。

Neovim：

```vim
:lua =vim.fn.has('clipboard')   " 1
:lua =vim.g.clipboard            " osc52（SSH 下）
:echo &clipboard                 " 空
```

normal 模式复制当前行：`<space>yy`；visual 选中后：`<space>y`。

## 7. 已知限制

- OSC 52 主要解决“远程 → 本地”的复制；读方向支持不统一。
- MobaXterm/PuTTY 不支持 OSC 52；如果使用它们，只能用终端鼠标选择，或另配 X11/xclip，
  但这不是 `dev_env` 的默认方案。
- tmux 3.7+ 的 `get-clipboard` 默认 `buffer`，应用读取剪贴板可能得到 tmux 最新 buffer；
  dev_env 在 tmux 内不执行 `<leader>p` 读取，但其他程序仍可能读取，必要时自行设置
  `get-clipboard off`（3.7+）或评估 `request`。
- 终端或 tmux 可能有 OSC 52 大小限制。
- 本地 VTE（GNOME Terminal 等）不支持 OSC 52；未安装原生工具时 Neovim 启动会提示改用支持的终端或安装 `xclip`/`wl-clipboard`。
- 远程程序可以写本地剪贴板，属于可信环境假设。

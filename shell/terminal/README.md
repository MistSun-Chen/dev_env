# Terminal color profiles

All profiles use the Catppuccin Mocha palette defined in
[`palette.env`](./palette.env). The installer copies this directory to:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/dev_env/terminal/
```

It does **not** modify terminal preferences automatically, with one exception:
**Ghostty** 的配置是纯文本，由 dev_env 直接管理并链接到
`~/.config/ghostty/config`。其他终端仍需手动导入配色文件，避免覆盖已有配置。

## Ghostty（macOS / Linux）

dev_env 管理的文件：[`ghostty/config`](./ghostty/config)。

- 主题：Ghostty 内置的 `Catppuccin Mocha`；
- 字体：`MesloLGS NF` 14（与 iTerm2 配置一致）；
- 窗口：120×38、8px 留白；
- 剪贴板：允许写入、读取保持询问（`ask`），配合 nvim 的 OSC 52 和 tmux 的 `set-clipboard`；
- SSH：启用 `ssh-env` / `ssh-terminfo`。从 Ghostty 里执行 `ssh` 时会自动在远端安装
  `xterm-ghostty` terminfo；远端没有 `tic` 时回退到 `xterm-256color`。

安装脚本会把本文件链接到 `~/.config/ghostty/config`。手动验证：

```sh
ghostty +validate-config
ghostty +show-config
```

首次 SSH 到新主机时，Ghostty 的 shell 集成会调用 `ghostty +ssh` 完成 terminfo 安装；
也可以手动执行：

```sh
ghostty +ssh user@host
```

## macOS: iTerm2

1. Open iTerm2 → Settings → Profiles → Colors.
2. Open the **Color Presets** menu → **Import**.
3. Select `iterm2/Catppuccin Mocha.itermcolors`.
4. Select the imported preset.
5. Choose the Meslo Nerd Font in the profile's Text settings.

The profile comes from the official Catppuccin port:
<https://github.com/catppuccin/iterm> (MIT).

## macOS: Terminal.app

1. Open `apple-terminal/Catppuccin Mocha.terminal` (double-click or `open`).
2. Terminal imports it as a profile named **Catppuccin Mocha**.
3. Select it under Settings → Profiles.
4. Set the Meslo Nerd Font in the profile's Text settings.

The profile comes from the official Catppuccin port:
<https://github.com/catppuccin/Terminal.app> (MIT).

## Linux: GNOME Terminal

The opt-in script applies the palette to the current default profile:

```sh
bash gnome-terminal/apply.sh
```

It uses `gsettings` and will overwrite that profile's colors. If you prefer to
keep the existing profile, create a new GNOME Terminal profile first and make
it the default.

## Linux: Kitty

Append or include the installed copy in `~/.config/kitty/kitty.conf`:

```conf
include ~/.local/share/dev_env/terminal/kitty/mocha.conf
```

The profile comes from <https://github.com/catppuccin/kitty> (MIT).

## Linux: WezTerm

Use the installed TOML directly (WezTerm can load a color scheme file):

```lua
local wezterm = require('wezterm')
return {
  colors = wezterm.color.load_scheme(
    wezterm.home_dir .. '/.local/share/dev_env/terminal/wezterm/catppuccin-mocha.toml'
  ),
}
```

Or copy the `[colors]` table into your own config. Source:
<https://github.com/catppuccin/wezterm> (MIT).

## Linux: Alacritty

Append the contents of `alacritty/catppuccin-mocha.toml` to
`~/.config/alacritty/alacritty.toml`. Source:
<https://github.com/catppuccin/alacritty> (MIT).

## Linux: Konsole

Copy `konsole/catppuccin-mocha.colorscheme` to:

```text
~/.local/share/konsole/
```

Then select **Catppuccin Mocha** in Konsole → Edit Current Profile → Appearance.
Source: <https://github.com/catppuccin/konsole> (MIT).

## VS Code integrated terminal

Merge `vscode/settings.json` into your VS Code `settings.json`. To use the
Nerd Font in the integrated terminal, also set:

```json
{
  "terminal.integrated.fontFamily": "MesloLGS Nerd Font"
}
```

The exact font family name depends on the installed Nerd Font package; check
your terminal/font picker if it differs.

## Other terminals

Use [`palette.env`](./palette.env) as the canonical 16-color palette. The
important values are `BASE`, `TEXT`, `ROSEWATER`, and the `ANSI_*` entries.
Keep the ANSI order (black, red, green, yellow, blue, magenta, cyan, white)
and the bright variants.

## Font

The Nerd Font is installed by the platform installer:

- macOS: `~/Library/Fonts`
- Linux: `~/.local/share/fonts` + `fc-cache -f`

The terminal profile still needs the font selected manually.

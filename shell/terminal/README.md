# Terminal color profiles

All profiles use the Catppuccin Mocha palette defined in
[`palette.env`](./palette.env). The installer copies this directory to:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/dev_env/terminal/
```

It does **not** modify terminal preferences automatically. Import the profile
once in each terminal you use; this avoids overwriting existing profiles.

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

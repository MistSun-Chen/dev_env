# Nerd Font

The shell prompt uses Starship's Catppuccin Powerline preset, which requires a
Nerd Font for its icons.

- Upstream: <https://github.com/ryanoasis/nerd-fonts>
- Version: `3.5.1`
- Asset: `Meslo.tar.xz`
- SHA256: `6b6624632dc6873dfb7681c3f818e7c01ab601ab707690b6440933bbe57e2b11`
- Installed subset: `MesloLGSNerdFont-{Regular,Bold,Italic,BoldItalic}.ttf`
- License: see the license files inside the Nerd Fonts release.

The platform installers download this asset on connected machines and include
it in the offline bundle. Installation targets:

- macOS: `~/Library/Fonts`
- Linux: `~/.local/share/fonts` followed by `fc-cache -f`

The terminal profile still needs the font selected manually. The font family
name may appear as `MesloLGS Nerd Font` or a variant such as
`MesloLGS NF`; use the name shown by the terminal's font picker.

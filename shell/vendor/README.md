# Vendored third-party code

The zsh plugins are pure zsh, so they work offline without a plugin manager.
`2clip/` is a shell script installed as a command, not sourced by zsh.

| Directory | Version | License |
|---|---|---|
| `zsh-autosuggestions/` | v0.7.1 | MIT (`LICENSE`) |
| `zsh-syntax-highlighting/` | 0.8.0 | BSD-3-Clause (`COPYING.md`) |
| `2clip/` | `bf7e9bc` (2026-05-09) | MIT (`LICENSE`) |

`zsh-autosuggestions` is loaded from `plugins.zsh`; `zsh-syntax-highlighting`
is sourced last by `zshrc`. Do not add Zinit/Oh My Zsh for these two plugins.

`zsh-syntax-highlighting` keeps upstream `.version` and `.revision-hash`;
both are required by its loader. Keep them when upgrading the vendored copy.

`2clip` is installed to `~/.local/bin/2clip` by `dev_env_install_2clip`
(`platforms/lib/common.sh`). Keep it byte-identical to upstream; see its
`README.md` for the pinned commit and usage notes.

When upgrading, replace the directory from the upstream release tag/commit,
keep the license file, and update this table.

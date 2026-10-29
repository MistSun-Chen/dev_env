# Vendored zsh plugins

Both are pure zsh, so they work offline without a plugin manager.

| Directory | Version | License |
|---|---|---|
| `zsh-autosuggestions/` | v0.7.1 | MIT (`LICENSE`) |
| `zsh-syntax-highlighting/` | 0.8.0 | BSD-3-Clause (`COPYING.md`) |

`zsh-autosuggestions` is loaded from `plugins.zsh`; `zsh-syntax-highlighting`
is sourced last by `zshrc`. Do not add Zinit/Oh My Zsh for these two plugins.

`zsh-syntax-highlighting` keeps upstream `.version` and `.revision-hash`;
both are required by its loader. Keep them when upgrading the vendored copy.

When upgrading, replace the directory from the upstream release tag, keep the
license file, and update this table.

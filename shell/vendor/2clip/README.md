# 2clip

Vendored from <https://github.com/rguziy/2clip> at commit
`bf7e9bc880c38b43e6d16a2c63b0d92640404506` (2026-05-09), MIT.

`2clip.sh` is installed to `~/.local/bin/2clip` by `dev_env_install_2clip`
(`platforms/lib/common.sh`). It writes the OSC 52 escape sequence to stdout, so
run it directly in an interactive terminal; redirecting stdout will discard the
clipboard write.

Keep the script byte-identical to upstream when upgrading, and update the
commit hash above.

- Upstream: <https://github.com/rguziy/2clip>
- License: MIT, see `LICENSE`.

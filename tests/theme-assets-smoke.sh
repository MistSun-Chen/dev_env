#!/usr/bin/env bash
#
# Validate terminal color assets and palette consistency.
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERMINAL_DIR="$REPO_ROOT/shell/terminal"

die() { printf '[theme-smoke] %s\n' "$*" >&2; exit 1; }
log() { printf '[theme-smoke] %s\n' "$*"; }

for f in \
  "$TERMINAL_DIR/palette.env" \
  "$TERMINAL_DIR/README.md" \
  "$TERMINAL_DIR/iterm2/Catppuccin Mocha.itermcolors" \
  "$TERMINAL_DIR/apple-terminal/Catppuccin Mocha.terminal" \
  "$TERMINAL_DIR/kitty/mocha.conf" \
  "$TERMINAL_DIR/wezterm/catppuccin-mocha.toml" \
  "$TERMINAL_DIR/alacritty/catppuccin-mocha.toml" \
  "$TERMINAL_DIR/konsole/catppuccin-mocha.colorscheme" \
  "$TERMINAL_DIR/gnome-terminal/apply.sh" \
  "$TERMINAL_DIR/vscode/settings.json"; do
  [[ -f "$f" ]] || die "缺少 $f"
done

grep -q '^BASE=#1e1e2e$' "$TERMINAL_DIR/palette.env" || die "palette BASE 不对"
grep -q '^ANSI_RED=#f38ba8$' "$TERMINAL_DIR/palette.env" || die "palette ANSI_RED 不对"

if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$TERMINAL_DIR/iterm2/Catppuccin Mocha.itermcolors" >/dev/null
  plutil -lint "$TERMINAL_DIR/apple-terminal/Catppuccin Mocha.terminal" >/dev/null
else
  python3 - "$TERMINAL_DIR/iterm2/Catppuccin Mocha.itermcolors" "$TERMINAL_DIR/apple-terminal/Catppuccin Mocha.terminal" <<'PY'
import plistlib, sys
for path in sys.argv[1:]:
    with open(path, "rb") as f:
        plistlib.load(f)
PY
fi

python3 -m json.tool "$TERMINAL_DIR/vscode/settings.json" >/dev/null

grep -q '#1e1e2e' "$TERMINAL_DIR/kitty/mocha.conf"
grep -q '#1e1e2e' "$TERMINAL_DIR/wezterm/catppuccin-mocha.toml"
grep -q '#1e1e2e' "$TERMINAL_DIR/alacritty/catppuccin-mocha.toml"
grep -q '30,30,46' "$TERMINAL_DIR/konsole/catppuccin-mocha.colorscheme"

[[ -x "$TERMINAL_DIR/gnome-terminal/apply.sh" ]] || die "gnome-terminal/apply.sh 不可执行"

log "通过"

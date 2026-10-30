#!/usr/bin/env bash
#
# Isolated tmux config smoke test.
# Uses a private socket and never touches the user's default tmux server.
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMUX_BIN="${TMUX_BIN:-$(command -v tmux || true)}"

[[ -n "$TMUX_BIN" ]] || {
  echo "tmux 未安装，跳过 tmux-config-smoke.sh" >&2
  exit 0
}

# Make the C-b r run-shell command use the same tmux binary under test.
TMUX_DIR="$(cd -- "$(dirname -- "$TMUX_BIN")" && pwd)"
PATH="$TMUX_DIR:$PATH"
export PATH

log()  { printf '[tmux-smoke] %s\n' "$*"; }
warn() { printf '[tmux-smoke] %s\n' "$*" >&2; }
die()  { printf '[tmux-smoke] %s\n' "$*" >&2; exit 1; }

# shellcheck source=../platforms/lib/common.sh
. "$REPO_ROOT/platforms/lib/common.sh"

# Version strings are used in install paths; reject traversal before testing tmux.
dev_env_validate_tmux_version 3.8 || die "合法 tmux 版本被拒绝"
dev_env_validate_tmux_version 3.8a || die "合法 tmux 版本被拒绝"
if dev_env_validate_tmux_version '3.8/../..'; then
  die "非法 tmux 版本未被拒绝"
fi

TMP_HOME="$(mktemp -d)"
TMP_XDG="$(mktemp -d)"
SOCK="dev_env_tmux_smoke_$$_${RANDOM}"
cleanup() {
  if "$TMUX_BIN" -L "$SOCK" list-sessions >/dev/null 2>&1; then
    "$TMUX_BIN" -L "$SOCK" send-keys -t smoke 'exit' Enter >/dev/null 2>&1 || true
    sleep 0.3
    "$TMUX_BIN" -L "$SOCK" send-keys -t smoke C-c >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_HOME" "$TMP_XDG"
}
trap cleanup EXIT

printf 'legacy\n' > "$TMP_HOME/.tmux.conf"
mkdir -p "$TMP_XDG/tmux"
printf 'old xdg config\n' > "$TMP_XDG/tmux/tmux.conf"
HOME="$TMP_HOME" XDG_CONFIG_HOME="$TMP_XDG" \
  dev_env_deploy_tmux_config "$REPO_ROOT/tmux/tmux.conf" "$TMP_XDG"

CONF="$TMP_XDG/tmux/tmux.conf"
[[ -L "$CONF" ]] || die "tmux 配置不是软链接: $CONF"
[[ ! -e "$TMP_HOME/.tmux.conf" ]] || die "旧 ~/.tmux.conf 没有被移走"
find "$TMP_HOME" -maxdepth 1 -name '.tmux.conf.bak.*' | grep -q . || die "旧 ~/.tmux.conf 未备份"
find "$TMP_XDG/tmux" -maxdepth 1 -name 'tmux.conf.bak.*' | grep -q . || die "旧 XDG tmux 配置未备份"

assert_eq() {
  local got="$1" want="$2" label="$3"
  [[ "$got" == "$want" ]] || die "$label: got '$got', want '$want'"
}

assert_contains() {
  local got="$1" want="$2" label="$3"
  [[ "$got" == *"$want"* ]] || die "$label: '$got' does not contain '$want'"
}

# Deliberately do not pass -f: this also verifies tmux discovers the config
# through a custom XDG_CONFIG_HOME.
printf 'set -g @dev-env-smoke-reloaded 0\n' > "$TMP_HOME/.tmux.local.conf"
HOME="$TMP_HOME" XDG_CONFIG_HOME="$TMP_XDG" \
  "$TMUX_BIN" -L "$SOCK" new-session -d -s smoke

assert_eq "$("$TMUX_BIN" -L "$SOCK" show-options -gv prefix)" "C-b" "prefix"
assert_eq "$("$TMUX_BIN" -L "$SOCK" show-options -gv mouse)" "on" "mouse"
assert_eq "$("$TMUX_BIN" -L "$SOCK" show-options -gv history-limit)" "100000" "history-limit"
assert_eq "$("$TMUX_BIN" -L "$SOCK" show-options -gv focus-events)" "on" "focus-events"
assert_eq "$("$TMUX_BIN" -L "$SOCK" show-options -sgv escape-time)" "10" "escape-time"
assert_eq "$("$TMUX_BIN" -L "$SOCK" show-options -gwv mode-keys)" "vi" "mode-keys"
assert_contains "$("$TMUX_BIN" -L "$SOCK" show-options -gv status-style)" "#1e1e2e" "status-style"

assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix h)" "select-pane -L" "h"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix j)" "select-pane -D" "j"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix k)" "select-pane -U" "k"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix l)" "select-pane -R" "l"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix H)" "resize-pane -L 5" "H"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix J)" "resize-pane -D 5" "J"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix K)" "resize-pane -U 5" "K"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix L)" "resize-pane -R 5" "L"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix Tab)" "last-window" "Tab"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix C-l)" "switch-client -l" "C-l"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix r)" "source-file" "r"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix R)" "refresh-client" "R"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix '|')" "split-window -h" "|"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix '-')" "split-window -v" "-"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix c)" "new-window" "c"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix z)" "resize-pane -Z" "z"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix '[')" "copy-mode" "["
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix u)" "copy-mode -u" "u"
assert_contains "$("$TMUX_BIN" -L "$SOCK" list-keys -T prefix r)" "XDG_CONFIG_HOME" "r reload path"
[[ "$("$TMUX_BIN" -L "$SOCK" show-options -gv set-clipboard)" != "on" ]] \
  || die "set-clipboard 不应由 dev_env 开启"

# Reload through the same shell command used by C-b r, with custom XDG.
assert_eq "$("$TMUX_BIN" -L "$SOCK" show-options -gv @dev-env-smoke-reloaded)" "0" "local override"
printf 'set -g @dev-env-smoke-reloaded 1\n' > "$TMP_HOME/.tmux.local.conf"
HOME="$TMP_HOME" XDG_CONFIG_HOME="$TMP_XDG" \
  "$TMUX_BIN" -L "$SOCK" run-shell \
  'tmux source-file "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"'
sleep 0.3
assert_eq "$("$TMUX_BIN" -L "$SOCK" show-options -gv @dev-env-smoke-reloaded)" "1" "reload with XDG"

for key in v V C-v y Space Enter MouseDragEnd1Pane; do
  if "$TMUX_BIN" -L "$SOCK" list-keys -T copy-mode-vi "$key" 2>/dev/null | grep -q .; then
    die "copy-mode-vi 复制键未移除: $key"
  fi
done

log "通过"

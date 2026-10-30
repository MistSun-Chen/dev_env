#!/usr/bin/env bash
#
# Isolated zsh + Starship config smoke test.
# Never sources or modifies the user's real ~/.zshrc.
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ZSH_BIN="${ZSH_BIN:-$(command -v zsh || true)}"

[[ -n "$ZSH_BIN" ]] || {
  echo "zsh 未安装，跳过 shell-config-smoke.sh" >&2
  exit 0
}

log()  { printf '[shell-smoke] %s\n' "$*"; }
die()  { printf '[shell-smoke] %s\n' "$*" >&2; exit 1; }

# shellcheck disable=SC1091 # path is resolved at runtime from REPO_ROOT
. "$REPO_ROOT/platforms/lib/common.sh"

TMP_HOME="$(mktemp -d)"
TMP_XDG="$(mktemp -d)"
TMP_HOME_TEMPLATE="$(mktemp -d)"
TMP_XDG_TEMPLATE="$(mktemp -d)"
OUT_FILE="$(mktemp)"
cleanup() {
  rm -rf "$TMP_HOME" "$TMP_XDG" "$TMP_HOME_TEMPLATE" "$TMP_XDG_TEMPLATE"
  rm -f "$OUT_FILE"
}
trap cleanup EXIT

# Syntax check every shell file.
for f in "$REPO_ROOT"/shell/zshrc "$REPO_ROOT"/shell/*.zsh; do
  "$ZSH_BIN" -n "$f" || die "zsh -n 失败: $f"
done

# Deploy into the temporary HOME and verify the symlink/local-file contract.
printf 'old zshrc\n' > "$TMP_HOME/.zshrc"
mkdir -p "$TMP_HOME/.nvm"
printf 'export DEV_ENV_FAKE_NVM=1\n' > "$TMP_HOME/.nvm/nvm.sh"
HOME="$TMP_HOME" XDG_CONFIG_HOME="$TMP_XDG" \
  dev_env_deploy_shell_config "$REPO_ROOT/shell" "$TMP_XDG"

[[ -L "$TMP_HOME/.zshrc" ]] || die "$TMP_HOME/.zshrc 不是软链接"
[[ -L "$TMP_XDG/starship.toml" ]] || die "$TMP_XDG/starship.toml 不是软链接"
[[ -f "$TMP_HOME/.zshrc.local" ]] || die "$TMP_HOME/.zshrc.local 未创建"
[[ "$(stat -c %a "$TMP_HOME/.zshrc.local" 2>/dev/null || stat -f %Lp "$TMP_HOME/.zshrc.local")" == "600" ]] \
  || die "$TMP_HOME/.zshrc.local 权限不是 600"
# shellcheck disable=SC2016 # literal line expected in the generated file
grep -qxF 'source "$HOME/.nvm/nvm.sh"' "$TMP_HOME/.zshrc.local" \
  || die "检测到 nvm 时未自动启用"
printf 'export DEV_ENV_SMOKE=ok\n' > "$TMP_HOME/.zshrc.local"
HOME="$TMP_HOME" XDG_CONFIG_HOME="$TMP_XDG" \
  dev_env_deploy_shell_config "$REPO_ROOT/shell" "$TMP_XDG"
grep -q 'DEV_ENV_SMOKE=ok' "$TMP_HOME/.zshrc.local" || die "已有 ~/.zshrc.local 被覆盖"
! grep -q 'nvm.sh' "$TMP_HOME/.zshrc.local" || die "已有 ~/.zshrc.local 不应被自动修改"
find "$TMP_HOME" -maxdepth 1 -name '.zshrc.bak.*' | grep -q . || die "旧 ~/.zshrc 未备份"

# A pre-existing file identical to the shipped template is safe to auto-fill,
# but must be backed up first.
mkdir -p "$TMP_HOME_TEMPLATE/.nvm"
printf 'export DEV_ENV_FAKE_NVM=1\n' > "$TMP_HOME_TEMPLATE/.nvm/nvm.sh"
cp "$REPO_ROOT/shell/zshrc.local.example" "$TMP_HOME_TEMPLATE/.zshrc.local"
chmod 600 "$TMP_HOME_TEMPLATE/.zshrc.local"
HOME="$TMP_HOME_TEMPLATE" XDG_CONFIG_HOME="$TMP_XDG_TEMPLATE" \
  dev_env_deploy_shell_config "$REPO_ROOT/shell" "$TMP_XDG_TEMPLATE"
# shellcheck disable=SC2016 # literal line expected in the generated file
grep -qxF 'source "$HOME/.nvm/nvm.sh"' "$TMP_HOME_TEMPLATE/.zshrc.local" \
  || die "与模板一致的 ~/.zshrc.local 未自动补全 nvm"
find "$TMP_HOME_TEMPLATE" -maxdepth 1 -name '.zshrc.local.bak.*' | grep -q . \
  || die "自动补全前未备份 ~/.zshrc.local"

# A user-authored all-comments file is not the template and must stay untouched.
# shellcheck disable=SC2016 # literal line expected in the user file
printf '%s\n' '# my local notes' '# source "$HOME/.nvm/nvm.sh"' \
  > "$TMP_HOME_TEMPLATE/.zshrc.local"
chmod 600 "$TMP_HOME_TEMPLATE/.zshrc.local"
BEFORE_SUM="$(cksum < "$TMP_HOME_TEMPLATE/.zshrc.local")"
HOME="$TMP_HOME_TEMPLATE" XDG_CONFIG_HOME="$TMP_XDG_TEMPLATE" \
  dev_env_deploy_shell_config "$REPO_ROOT/shell" "$TMP_XDG_TEMPLATE"
AFTER_SUM="$(cksum < "$TMP_HOME_TEMPLATE/.zshrc.local")"
[[ "$BEFORE_SUM" == "$AFTER_SUM" ]] || die "用户自写的注释文件被修改"
# shellcheck disable=SC2016 # literal line expected in the user file
grep -qxF '# source "$HOME/.nvm/nvm.sh"' "$TMP_HOME_TEMPLATE/.zshrc.local" \
  || die "用户注释的 nvm 行被取消注释"

cat > "$TMP_HOME/check.zsh" <<'EOF'
source "$HOME/.zshrc"
[[ -n "${PROMPT:-}" ]] || { print -u2 'PROMPT empty'; exit 1; }
if (( $+commands[nvim] )); then
  alias vim | grep -q 'nvim' || { print -u2 'vim alias missing'; exit 1; }
else
  print 'nvim not installed; skip vim alias check'
fi
alias ll >/dev/null || { print -u2 'll alias missing'; exit 1; }
[[ "${path[1]}" == "$HOME/.local/bin" ]] || { print -u2 "PATH first is ${path[1]}"; exit 1; }
[[ "${DEV_ENV_SMOKE:-}" == "ok" ]] || { print -u2 'local override not loaded'; exit 1; }
[[ -n "${DEV_ENV_SHELL_DIR:-}" ]] || { print -u2 'DEV_ENV_SHELL_DIR empty'; exit 1; }
[[ -n "${functions[_zsh_autosuggest_start]:-}" ]] || { print -u2 'autosuggestions missing'; exit 1; }
[[ -n "${functions[_zsh_highlight]:-}" ]] || { print -u2 'syntax-highlighting missing'; exit 1; }
[[ "$(bindkey '^[[1;3D')" == *backward-word* ]] || { print -u2 'Option+Left binding missing'; exit 1; }
[[ "$(bindkey '^[[1;3C')" == *forward-word* ]] || { print -u2 'Option+Right binding missing'; exit 1; }
print "PROMPT_OK=${PROMPT}"
EOF

HOME="$TMP_HOME" ZDOTDIR="$TMP_HOME" "$ZSH_BIN" -f -i "$TMP_HOME/check.zsh" >"$OUT_FILE" 2>&1 \
  || { cat "$OUT_FILE" >&2; die "zsh 配置加载失败"; }
grep -q 'PROMPT_OK=' "$OUT_FILE" || die "PROMPT 未设置"

STARSHIP_BIN="${STARSHIP_BIN:-$(command -v starship || true)}"
if [[ -n "$STARSHIP_BIN" ]]; then
  STARSHIP_CONFIG="$REPO_ROOT/shell/starship.toml" "$STARSHIP_BIN" prompt >/dev/null \
    || die "starship prompt 失败"
  log "Starship prompt 通过"

  # A stale override must not silently downgrade the prompt to Starship's default.
  # shellcheck disable=SC2016 # evaluated by zsh after .zshrc is sourced
  HOME="$TMP_HOME" ZDOTDIR="$TMP_HOME" \
    STARSHIP_CONFIG="$TMP_HOME/missing-starship.toml" \
    "$ZSH_BIN" -f -i -c '
      source "$HOME/.zshrc"
      [[ "$STARSHIP_CONFIG" == "$DEV_ENV_SHELL_DIR/starship.toml" ]] || {
        print -u2 "stale STARSHIP_CONFIG not replaced: $STARSHIP_CONFIG"
        exit 1
      }
    ' || die "STARSHIP_CONFIG 回退失败"
  log "Starship 配置回退通过"
else
  log "Starship 未安装，跳过 prompt 检查"
fi

log "通过"

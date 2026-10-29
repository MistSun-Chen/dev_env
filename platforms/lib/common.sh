#!/usr/bin/env bash
# Shared helpers for dev_env platform installers.
# Source this file; do not execute it directly.

dev_env_log() {
  if declare -F log >/dev/null 2>&1; then
    log "$@"
  else
    printf '[dev_env] %s\n' "$*"
  fi
}

dev_env_warn() {
  if declare -F warn >/dev/null 2>&1; then
    warn "$@"
  else
    printf '[dev_env] %s\n' "$*" >&2
  fi
}

# Portable canonical path. macOS readlink(1) has no reliable -f.
dev_env_canonical_path() {
  local path="$1"
  local target

  if [[ -L "$path" ]]; then
    target="$(readlink "$path")"
    case "$target" in
      /*) path="$target" ;;
      *) path="$(dirname -- "$path")/$target" ;;
    esac
  fi

  if [[ -d "$path" ]]; then
    (cd -- "$path" && pwd -P)
  elif [[ -e "$path" ]]; then
    (cd -- "$(dirname -- "$path")" && printf '%s/%s\n' "$(pwd -P)" "$(basename -- "$path")")
  else
    printf '%s\n' "$path"
  fi
}

dev_env_backup_path() {
  local path="$1"
  local backup

  backup="${path}.bak.$(date +%Y%m%d-%H%M%S)"
  while [[ -e "$backup" || -L "$backup" ]]; do
    backup="${backup}-$$"
  done
  printf '%s\n' "$backup"
}

# dev_env_link_path <source> <destination> [label]
# Idempotent: skip when destination already points at source.
dev_env_link_path() {
  local src="$1"
  local dest="$2"
  local label="${3:-配置}"
  local src_real
  local dest_real
  local backup

  src_real="$(dev_env_canonical_path "$src")"

  if [[ -L "$dest" ]]; then
    dest_real="$(dev_env_canonical_path "$dest")"
    if [[ "$dest_real" == "$src_real" ]]; then
      dev_env_log "${label}已经链接到目标，跳过。"
      return 0
    fi
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    backup="$(dev_env_backup_path "$dest")"
    mv "$dest" "$backup"
    dev_env_log "已备份旧${label}: $backup"
  fi

  install -d "$(dirname -- "$dest")"
  ln -sfn "$src" "$dest"
  dev_env_log "已链接${label}: $dest -> $src"
}

dev_env_deploy_nvim_config() {
  local src="$1"
  local xdg_config_home="${2:-${XDG_CONFIG_HOME:-$HOME/.config}}"

  dev_env_link_path "$src" "$xdg_config_home/nvim" "Neovim 配置"
}

dev_env_deploy_tmux_config() {
  local src="$1"
  local xdg_config_home="${2:-${XDG_CONFIG_HOME:-$HOME/.config}}"
  local dest="$xdg_config_home/tmux/tmux.conf"
  local legacy="$HOME/.tmux.conf"
  local backup

  # tmux may prefer ~/.tmux.conf over the XDG file; move it out of the way
  # (after backing it up) so there is only one active config.
  if [[ -e "$legacy" || -L "$legacy" ]]; then
    if [[ -L "$legacy" && "$(dev_env_canonical_path "$legacy")" == "$(dev_env_canonical_path "$src")" ]]; then
      :
    else
      backup="$(dev_env_backup_path "$legacy")"
      mv "$legacy" "$backup"
      dev_env_log "已备份旧的 ~/.tmux.conf: $backup"
    fi
  fi

  dev_env_link_path "$src" "$dest" "tmux 配置"
}

dev_env_deploy_shell_config() {
  local shell_dir="$1"
  local xdg_config_home="${2:-${XDG_CONFIG_HOME:-$HOME/.config}}"
  local local_file="$HOME/.zshrc.local"
  local example="$shell_dir/zshrc.local.example"

  dev_env_link_path "$shell_dir/zshrc" "$HOME/.zshrc" "zsh 配置"
  dev_env_link_path "$shell_dir/starship.toml" "$xdg_config_home/starship.toml" "Starship 配置"

  if [[ ! -e "$local_file" && ! -L "$local_file" ]]; then
    if [[ -f "$example" ]]; then
      install -m 600 "$example" "$local_file"
      dev_env_log "已创建 ${local_file}（chmod 600）；请把机器相关配置迁移进去。"
    else
      dev_env_warn "缺少 ${example}，未创建 ~/.zshrc.local。"
    fi
  else
    dev_env_log "$local_file 已存在，保持不动。"
  fi
}

dev_env_deploy_terminal_assets() {
  local shell_dir="$1"
  local data_home="${2:-${XDG_DATA_HOME:-$HOME/.local/share}}"
  local dst="$data_home/dev_env/terminal"

  if [[ -d "$shell_dir/terminal" ]]; then
    install -d "$dst"
    cp -a "$shell_dir/terminal/." "$dst/"
    dev_env_log "已复制终端配色资源: $dst"
  fi
}

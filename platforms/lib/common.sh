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

# Validate a tmux version before using it in a filesystem path.
# Accepts 3.8, 3.8a, 3.8.1, etc.; rejects slashes and "..".
dev_env_validate_tmux_version() {
  local version="$1"
  [[ "$version" =~ ^[0-9]+([.][0-9]+)*[a-z]?$ ]]
}

# Portable canonical path. macOS readlink(1) has no reliable -f.
dev_env_canonical_path() {
  # Avoid the name "path": in zsh it is tied to the PATH array and would
  # clobber command lookup if this file is ever sourced outside bash.
  local source_path="$1"
  local target

  if [[ -L "$source_path" ]]; then
    target="$(readlink "$source_path")"
    case "$target" in
      /*) source_path="$target" ;;
      *) source_path="$(dirname -- "$source_path")/$target" ;;
    esac
  fi

  if [[ -d "$source_path" ]]; then
    (cd -- "$source_path" && pwd -P)
  elif [[ -e "$source_path" ]]; then
    (cd -- "$(dirname -- "$source_path")" && printf '%s/%s\n' "$(pwd -P)" "$(basename -- "$source_path")")
  else
    printf '%s\n' "$source_path"
  fi
}

dev_env_backup_path() {
  local target_path="$1"
  local backup

  backup="${target_path}.bak.$(date +%Y%m%d-%H%M%S)"
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
  # Link to the resolved source: callers may pass a relative path, and a
  # relative symlink target would be interpreted relative to the destination.
  ln -sfn "$src_real" "$dest"
  dev_env_log "已链接${label}: $dest -> $src_real"
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

# Offline bundles are often extracted under /tmp or ~/Downloads and deleted
# after installation. Copy their config trees to a stable data directory so
# ~/.zshrc and friends do not become dangling symlinks.
# Prints the destination directory; callers should log it themselves.
dev_env_stage_configs() {
  local bundle="$1"
  local data_home="${2:-${XDG_DATA_HOME:-$HOME/.local/share}}"
  local dst="$data_home/dev_env/config"
  local name

  [[ -d "$bundle/nvim" && -d "$bundle/tmux" && -d "$bundle/shell" ]] \
    || {
      dev_env_warn "离线包缺少 nvim/tmux/shell 配置目录: $bundle"
      return 1
    }

  install -d "$dst"
  for name in nvim tmux shell; do
    rm -rf "${dst:?}/$name"
    cp -a "$bundle/$name" "$dst/$name"
  done
  printf '%s\n' "$dst"
}

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

# Rewrite a file without changing its inode/permissions.
dev_env_rewrite_file() {
  local file="$1"
  local tmp

  tmp="$(mktemp "${file}.dev_env.XXXXXX")" || return 1
  if ! cat > "$tmp" || ! cat "$tmp" > "$file"; then
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
}

# Replace every literal occurrence in a file.
dev_env_replace_literal() {
  local file="$1"
  local from="$2"
  local to="$3"
  local line

  {
    while IFS= read -r line || [[ -n "$line" ]]; do
      printf '%s\n' "${line//$from/$to}"
    done < "$file"
  } | dev_env_rewrite_file "$file"
}

# Turn an exact commented line ("# <line>") into an active line.
dev_env_uncomment_exact_line() {
  local file="$1"
  local line="$2"
  local current

  {
    while IFS= read -r current || [[ -n "$current" ]]; do
      if [[ "$current" == "# $line" ]]; then
        printf '%s\n' "$line"
      else
        printf '%s\n' "$current"
      fi
    done < "$file"
  } | dev_env_rewrite_file "$file"
}

# Return the first common local proxy port that is actually listening.
dev_env_detect_proxy_port() {
  local port

  for port in 7897 7890; do
    if command -v lsof >/dev/null 2>&1 \
      && lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      printf '%s\n' "$port"
      return 0
    fi
    if command -v ss >/dev/null 2>&1 \
      && ss -lnt 2>/dev/null | grep -q ":${port}[[:space:]]"; then
      printf '%s\n' "$port"
      return 0
    fi
    if command -v netstat >/dev/null 2>&1 \
      && netstat -an 2>/dev/null | grep -Eq "[.:]${port}[[:space:]].*LISTEN"; then
      printf '%s\n' "$port"
      return 0
    fi
  done
  return 1
}

# Fill in the parts of a newly created ~/.zshrc.local that can be detected
# safely. Never enables a proxy: that changes network behavior, so the port
# is only filled into the commented example.
dev_env_autoconfigure_local() {
  local local_file="$1"
  # shellcheck disable=SC2016 # keep $HOME literal for the zsh config file
  local nvm_line='source "$HOME/.nvm/nvm.sh"'
  local proxy_port

  [[ -f "$local_file" ]] || return 0

  if [[ -f "$HOME/.nvm/nvm.sh" ]]; then
    if grep -qxF "$nvm_line" "$local_file"; then
      :
    elif grep -qxF "# $nvm_line" "$local_file"; then
      dev_env_uncomment_exact_line "$local_file" "$nvm_line"
      dev_env_log "检测到 nvm，已自动启用 ~/.nvm/nvm.sh。"
    else
      {
        printf '\n# dev_env: 检测到 nvm，自动启用\n'
        printf '%s\n' "$nvm_line"
      } >> "$local_file"
      dev_env_log "检测到 nvm，已自动追加初始化。"
    fi
  fi

  proxy_port="$(dev_env_detect_proxy_port || true)"
  if [[ -n "$proxy_port" ]]; then
    dev_env_replace_literal "$local_file" "127.0.0.1:7897" "127.0.0.1:${proxy_port}"
    dev_env_log "检测到本机代理监听 127.0.0.1:${proxy_port}；已更新模板端口（代理仍为注释，需要时再启用）。"
  fi
}

# True when a config file has at least one non-comment, non-blank line.
dev_env_local_has_custom_config() {
  grep -Eq '^[[:space:]]*[^#[:space:]]' "$1"
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
      dev_env_autoconfigure_local "$local_file"
      dev_env_log "已创建 ${local_file}（chmod 600）；可检测项已自动配置，其余按需取消注释。"
    else
      dev_env_warn "缺少 ${example}，未创建 ~/.zshrc.local。"
    fi
  elif [[ -f "$local_file" && ! -L "$local_file" ]] \
    && ! dev_env_local_has_custom_config "$local_file"; then
    # Only comments/blank lines: still the untouched template, so filling in
    # detectable values is safe. Never touch a file with custom active config.
    dev_env_autoconfigure_local "$local_file"
    dev_env_log "${local_file} 只有注释/空行，已自动补全可检测项。"
  else
    dev_env_log "$local_file 已存在且包含自定义配置，保持不动。"
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

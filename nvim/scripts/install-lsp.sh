#!/usr/bin/env bash
#
# 安装 dev_env 使用的 language server。可重复执行，已安装的会跳过。
# 需要联网；离线包不包含这些 server。
#
# 用法：
#   bash nvim/scripts/install-lsp.sh --components python,cpp,bash
#   bash nvim/scripts/install-lsp.sh --all
#   bash nvim/scripts/install-lsp.sh --none
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
. "$SCRIPT_DIR/versions.env"

COMPONENTS="python,cpp,bash"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_OPT="$HOME/.local/opt"

log() { printf '[lsp] %s\n' "$*"; }
die() { printf '[lsp] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
用法: install-lsp.sh [选项]

  --components <list>  逗号分隔: python,bash,cpp（默认 python,cpp,bash）
  --all                等同 --components python,cpp,bash
  --none               不安装任何 LSP
  -h, --help           显示帮助

说明:
  python  pyright（npm）
  bash    bash-language-server（npm）
  cpp     clangd（macOS: Xcode CLT；Ubuntu: apt）
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --components)
      [[ $# -ge 2 ]] || die "--components 需要参数"
      COMPONENTS="$2"
      shift 2
      ;;
    --all)
      COMPONENTS="python,cpp,bash"
      shift
      ;;
    --none)
      COMPONENTS=""
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "未知参数: $1（使用 --help 查看用法）"
      ;;
  esac
done

COMPONENTS="${COMPONENTS// /}"
case "$COMPONENTS" in
  all) COMPONENTS="python,cpp,bash" ;;
  none) COMPONENTS="" ;;
esac

if [[ -z "$COMPONENTS" ]]; then
  log "未选择 LSP 组件，跳过。"
  exit 0
fi

IFS=',' read -r -a COMPONENT_LIST <<< "$COMPONENTS"
for component in "${COMPONENT_LIST[@]}"; do
  case "$component" in
    python|bash|cpp) ;;
    *) die "未知组件: ${component}（可选 python,bash,cpp）" ;;
  esac
done

has_component() {
  [[ ",$COMPONENTS," == *",$1,"* ]]
}

ensure_node_npm() {
  command -v node >/dev/null 2>&1 \
    || die "需要 Node.js >= 18；Ubuntu: sudo apt install nodejs npm；macOS: brew install node"
  command -v npm >/dev/null 2>&1 \
    || die "需要 npm；Ubuntu: sudo apt install npm；macOS: brew install node"
  node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 18 ? 0 : 1)' \
    || die "Node.js 版本过低，需要 >= 18（当前 $(node --version)）"
}

install_npm_tool() {
  local pkg="$1"
  local version="$2"
  local prefix="$3"
  local bin="$4"
  local module_bin="$prefix/node_modules/.bin/$bin"
  local wrapper="$LOCAL_BIN/$bin"
  local tmp

  install -d "$prefix" "$LOCAL_BIN"
  if [[ -x "$module_bin" ]]; then
    log "$pkg@$version 已存在，跳过 npm 安装。"
  else
    log "安装 $pkg@$version ..."
    npm install --prefix "$prefix" --no-fund --no-audit "$pkg@$version"
  fi
  [[ -x "$module_bin" ]] || die "安装后找不到 $module_bin"

  tmp="$(mktemp "$LOCAL_BIN/.${bin}.XXXXXX")"
  {
    printf '#!/bin/sh\n'
    printf 'exec "%s" "$@"\n' "$module_bin"
  } > "$tmp"
  chmod 755 "$tmp"
  mv -f "$tmp" "$wrapper"
  log "已安装 $wrapper"
}

install_clangd_linux() {
  local -a sudo_cmd=()

  command -v apt-get >/dev/null 2>&1 || die "未找到 apt-get；请手动安装 clangd"
  if [[ "${EUID}" -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || die "需要 sudo 安装 clangd"
    sudo_cmd=(sudo)
  fi

  # macOS 的 /bin/bash 3.2 在 set -u 下展开空数组会报错；分开处理。
  apt_install() {
    if [[ ${#sudo_cmd[@]} -gt 0 ]]; then
      "${sudo_cmd[@]}" env DEBIAN_FRONTEND=noninteractive apt-get "$@"
    else
      env DEBIAN_FRONTEND=noninteractive apt-get "$@"
    fi
  }

  log "安装 clangd ..."
  apt_install install -y --no-install-recommends clangd \
    || die "clangd 安装失败；请先运行 sudo apt-get update"

  if ! command -v g++ >/dev/null 2>&1 && ! command -v clang++ >/dev/null 2>&1; then
    log "安装 g++（C++ 标准库头文件）..."
    apt_install install -y --no-install-recommends g++ \
      || die "g++ 安装失败"
  fi
  command -v clangd >/dev/null 2>&1 || die "clangd 安装后仍找不到"
}

install_clangd() {
  local clangd_path

  if command -v clangd >/dev/null 2>&1; then
    log "clangd 已存在: $(command -v clangd)"
    return
  fi

  case "$(uname -s)" in
    Darwin)
      clangd_path="$(xcrun --find clangd 2>/dev/null || true)"
      [[ -n "$clangd_path" && -x "$clangd_path" ]] \
        || die "未找到 clangd；请先执行 xcode-select --install"
      install -d "$LOCAL_BIN"
      ln -sfn "$clangd_path" "$LOCAL_BIN/clangd"
      log "已链接 clangd: $LOCAL_BIN/clangd -> $clangd_path"
      ;;
    Linux)
      install_clangd_linux
      ;;
    *)
      die "不支持的平台: $(uname -s)"
      ;;
  esac
}

if has_component python || has_component bash; then
  ensure_node_npm
fi

if has_component python; then
  install_npm_tool pyright "$PYRIGHT_VERSION" \
    "$LOCAL_OPT/pyright-$PYRIGHT_VERSION" pyright-langserver
fi

if has_component bash; then
  install_npm_tool bash-language-server "$BASH_LANGUAGE_SERVER_VERSION" \
    "$LOCAL_OPT/bash-language-server-$BASH_LANGUAGE_SERVER_VERSION" bash-language-server
fi

if has_component cpp; then
  install_clangd
fi

log "LSP 安装完成。"

#!/usr/bin/env bash
#
# 在 Docker 中测试 Ubuntu 24.04 离线安装
#
# 步骤：
#   1. 在联网容器中生成离线包
#   2. 在 --network none 的全新容器中安装
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUNDLE_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$BUNDLE_DIR"
}
trap cleanup EXIT

DOCKER_ENV=()
if [[ -n "${DOCKER_PROXY:-}" ]]; then
  DOCKER_ENV=(-e "http_proxy=${DOCKER_PROXY}" -e "https_proxy=${DOCKER_PROXY}")
fi
if [[ -n "${DOCKER_NO_PROXY:-}" ]]; then
  DOCKER_ENV+=(-e "no_proxy=${DOCKER_NO_PROXY}" -e "NO_PROXY=${DOCKER_NO_PROXY}")
fi
if [[ -n "${DOCKER_APT_MIRROR:-}" ]]; then
  DOCKER_ENV+=(-e "DOCKER_APT_MIRROR=${DOCKER_APT_MIRROR}")
fi

command -v docker >/dev/null 2>&1 || {
  echo "找不到 docker" >&2
  exit 1
}
docker info >/dev/null 2>&1 || {
  echo "Docker daemon 没有运行" >&2
  exit 1
}

echo "[test] 1/2 生成离线包（联网容器）"
docker run --rm \
  ${DOCKER_ENV[@]+"${DOCKER_ENV[@]}"} \
  -v "$REPO_ROOT:/work:ro" \
  -v "$BUNDLE_DIR:/bundle" \
  ubuntu:24.04 \
  bash -lc '
    set -euo pipefail
    if [[ -n "${DOCKER_APT_MIRROR:-}" ]]; then
      sed -i "s|http://ports.ubuntu.com/ubuntu-ports|${DOCKER_APT_MIRROR}|g; s|http://archive.ubuntu.com/ubuntu|${DOCKER_APT_MIRROR}|g; s|http://security.ubuntu.com/ubuntu|${DOCKER_APT_MIRROR}|g" /etc/apt/sources.list.d/ubuntu.sources
    fi
    cd /work/platforms/linux/ubuntu/24.04/offline
    bash download.sh --output /bundle --no-tar --allow-root
  '

echo "[test] 离线包内容："
find "$BUNDLE_DIR" -maxdepth 1 -type f | sort
find "$BUNDLE_DIR/debs" -maxdepth 1 -name '*.deb' | sort | grep -E '/(zsh|zsh-common|ncurses-term|xz-utils|libncurses6|libncursesw6|libtinfo6|libutempter)' || true
du -sh "$BUNDLE_DIR"

for f in "$BUNDLE_DIR/shell/zshrc" "$BUNDLE_DIR/shell/starship.toml" "$BUNDLE_DIR/lib/common.sh"; do
  [[ -e "$f" ]] || { echo "缺少 $f" >&2; exit 1; }
done
ls "$BUNDLE_DIR"/Meslo.tar.xz >/dev/null || { echo "缺少 Meslo.tar.xz" >&2; exit 1; }
[[ -f "$BUNDLE_DIR/tmux-bin" ]] || { echo "缺少 tmux-bin" >&2; exit 1; }
[[ -f "$BUNDLE_DIR/tmux-build-info.txt" ]] || { echo "缺少 tmux-build-info.txt" >&2; exit 1; }
compgen -G "$BUNDLE_DIR/debs/zsh*.deb" >/dev/null || { echo "缺少 zsh deb" >&2; exit 1; }

echo "[test] 2/2 在无网络容器中安装"
docker run --rm --network none \
  -v "$BUNDLE_DIR:/bundle:ro" \
  ubuntu:24.04 \
  bash -lc '
    set -euo pipefail
    bash /bundle/install.sh --allow-root
    CONFIG_ROOT=/root/.local/share/dev_env/config
    PATH="/root/.local/bin:$PATH" /root/.local/bin/nvim --headless \
      "+lua if vim.o.number ~= true or vim.g.colors_name ~= \"catppuccin-mocha\" then error(\"config smoke failed\") end" +qa
    /root/.local/bin/tmux -V
    test "$(/root/.local/bin/tmux -V)" = "tmux 3.8"
    /usr/bin/zsh --version
    /root/.local/bin/starship --version
    test -f "$CONFIG_ROOT/shell/zshrc"
    test -f "$CONFIG_ROOT/nvim/init.lua"
    test -L /root/.zshrc
    test -L /root/.config/tmux/tmux.conf
    test -L /root/.config/starship.toml
    case "$(readlink -f /root/.zshrc)" in "$CONFIG_ROOT"/*) ;; *) exit 1 ;; esac
    case "$(readlink -f /root/.config/nvim)" in "$CONFIG_ROOT"/*) ;; *) exit 1 ;; esac
    test -f /root/.zshrc.local
    test "$(stat -c %a /root/.zshrc.local)" = 600
    /usr/bin/zsh -n /root/.zshrc
    # No -f: verify config discovery, not just explicit loading.
    /root/.local/bin/tmux -L dev-env-ci new-session -d -s smoke
    test "$(/root/.local/bin/tmux -L dev-env-ci show-options -gv prefix)" = C-b
    test "$(/root/.local/bin/tmux -L dev-env-ci show-options -gv mouse)" = on
    /root/.local/bin/tmux -L dev-env-ci list-keys -T prefix H | grep -q "resize-pane -L 5"
    /root/.local/bin/tmux -L dev-env-ci list-keys -T prefix r | grep -q "XDG_CONFIG_HOME"
    /root/.local/bin/tmux -L dev-env-ci send-keys -t smoke "exit" Enter

    # --skip-config must not remove an existing plugin tree or parser.
    mkdir -p /root/.local/share/nvim/lazy/fzf-lua
    printf "keep\n" > /root/.local/share/nvim/lazy/fzf-lua/.dev_env-keep
    printf "keep\n" > /root/.local/share/nvim/site/parser/latex.so
    bash /bundle/install.sh --allow-root --skip-config
    test -f /root/.local/share/nvim/lazy/fzf-lua/.dev_env-keep
    grep -q keep /root/.local/share/nvim/site/parser/latex.so
  '

echo "[test] 通过"

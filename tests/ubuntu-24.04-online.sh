#!/usr/bin/env bash
#
# 在 Docker 中测试 Ubuntu 24.04 联网安装
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

echo "[test] Ubuntu 24.04 联网安装"
docker run --rm \
  ${DOCKER_ENV[@]+"${DOCKER_ENV[@]}"} \
  -v "$REPO_ROOT:/work:ro" \
  ubuntu:24.04 \
  bash -lc '
    set -euo pipefail
    if [[ -n "${DOCKER_APT_MIRROR:-}" ]]; then
      sed -i "s|http://ports.ubuntu.com/ubuntu-ports|${DOCKER_APT_MIRROR}|g; s|http://archive.ubuntu.com/ubuntu|${DOCKER_APT_MIRROR}|g; s|http://security.ubuntu.com/ubuntu|${DOCKER_APT_MIRROR}|g" /etc/apt/sources.list.d/ubuntu.sources
    fi
    cp -a /work /tmp/work
    bash /tmp/work/platforms/linux/ubuntu/24.04/install.sh --allow-root
    PATH="/root/.local/bin:$PATH" /root/.local/bin/nvim --headless \
      "+lua if vim.o.number ~= true or vim.g.colors_name ~= \"catppuccin-mocha\" then error(\"config smoke failed\") end" +qa
    /root/.local/bin/tmux -V
    test "$(/root/.local/bin/tmux -V)" = "tmux 3.8"
    /usr/bin/zsh --version
    /root/.local/bin/starship --version
    test -L /root/.zshrc
    test -L /root/.config/tmux/tmux.conf
    test -L /root/.config/starship.toml
    test -f /root/.zshrc.local
    test "$(stat -c %a /root/.zshrc.local)" = 600
    /usr/bin/zsh -n /root/.zshrc
    # No -f: verify tmux discovers ~/.config/tmux/tmux.conf on Ubuntu 24.04.
    /root/.local/bin/tmux -L dev-env-ci new-session -d -s smoke
    test "$(/root/.local/bin/tmux -L dev-env-ci show-options -gv prefix)" = C-b
    test "$(/root/.local/bin/tmux -L dev-env-ci show-options -gv mouse)" = on
    /root/.local/bin/tmux -L dev-env-ci list-keys -T prefix h | grep -q "select-pane -L"
    /root/.local/bin/tmux -L dev-env-ci list-keys -T prefix r | grep -q "XDG_CONFIG_HOME"
    /root/.local/bin/tmux -L dev-env-ci send-keys -t smoke "exit" Enter
  '

echo "[test] 通过"

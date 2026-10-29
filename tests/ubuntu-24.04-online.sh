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
    cp -a /work /tmp/work
    bash /tmp/work/platforms/linux/ubuntu/24.04/install.sh --allow-root
    PATH="/root/.local/bin:$PATH" /root/.local/bin/nvim --headless \
      "+lua if vim.o.number ~= true or vim.g.colors_name ~= \"catppuccin-mocha\" then error(\"config smoke failed\") end" +qa
    /usr/bin/tmux -V
    /usr/bin/zsh --version
    /root/.local/bin/starship --version
    test -L /root/.zshrc
    test -L /root/.config/tmux/tmux.conf
    test -L /root/.config/starship.toml
    test -f /root/.zshrc.local
    test "$(stat -c %a /root/.zshrc.local)" = 600
    /usr/bin/zsh -n /root/.zshrc
    # No -f: verify tmux discovers ~/.config/tmux/tmux.conf on Ubuntu 24.04.
    /usr/bin/tmux -L dev-env-ci new-session -d -s smoke
    test "$(/usr/bin/tmux -L dev-env-ci show-options -gv prefix)" = C-b
    test "$(/usr/bin/tmux -L dev-env-ci show-options -gv mouse)" = on
    /usr/bin/tmux -L dev-env-ci list-keys -T prefix h | grep -q "select-pane -L"
    /usr/bin/tmux -L dev-env-ci list-keys -T prefix r | grep -q "XDG_CONFIG_HOME"
    /usr/bin/tmux -L dev-env-ci send-keys -t smoke "exit" Enter
  '

echo "[test] 通过"

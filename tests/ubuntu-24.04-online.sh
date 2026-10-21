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
  bash -lc 'cp -a /work /tmp/work && bash /tmp/work/platforms/linux/ubuntu/24.04/install.sh --allow-root && /root/.local/bin/nvim --headless +qa'

echo "[test] 通过"

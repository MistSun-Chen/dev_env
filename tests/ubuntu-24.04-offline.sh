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
  "${DOCKER_ENV[@]}" \
  -v "$REPO_ROOT:/work:ro" \
  -v "$BUNDLE_DIR:/bundle" \
  ubuntu:24.04 \
  bash -lc 'cd /work/platforms/linux/ubuntu/24.04/offline && bash download.sh --output /bundle --no-tar --allow-root'

echo "[test] 离线包内容："
find "$BUNDLE_DIR" -maxdepth 1 -type f | sort
du -sh "$BUNDLE_DIR"

echo "[test] 2/2 在无网络容器中安装"
docker run --rm --network none \
  -v "$BUNDLE_DIR:/bundle:ro" \
  ubuntu:24.04 \
  bash /bundle/install.sh --allow-root --skip-config

echo "[test] 通过"

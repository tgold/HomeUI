#!/usr/bin/env bash
#
# Cross-build HomeUI for Raspberry Pi OS (64-bit) using Docker.
#
# Uses a Debian 13 (trixie) arm64 image with the same Qt/apt packages as the panel.
# On Apple Silicon this runs natively; on x86_64 hosts Docker uses QEMU emulation.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${HOMEUI_PI_IMAGE:-homeui-pi-builder}"
PLATFORM="${HOMEUI_PI_PLATFORM:-linux/arm64}"
BUILD_DIR="${HOMEUI_PI_BUILD_DIR:-${REPO_ROOT}/build-pi-docker}"
DOCKERFILE="${REPO_ROOT}/docker/Dockerfile.pi-build"

BUILD_IMAGE_ONLY=0
FORCE_REBUILD=0
OPEN_SHELL=0

usage() {
  cat <<EOF
Usage: $0 [--image] [--rebuild-image] [--shell] [--build-dir <dir>]

  (default)       configure and compile HomeUI; output: build-pi-docker/homeui
  --image         build or refresh the Docker builder image only (no compile)
  --rebuild-image force a no-cache image rebuild, then compile
  --shell         open an interactive shell in the builder container
  --build-dir     override output directory (default: build-pi-docker/)

Environment:
  HOMEUI_PI_IMAGE      Docker image name (default: homeui-pi-builder)
  HOMEUI_PI_PLATFORM   Docker platform (default: linux/arm64)
  HOMEUI_PI_BUILD_DIR  CMake build directory on the host
EOF
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --image)          BUILD_IMAGE_ONLY=1; shift ;;
    --rebuild-image)  FORCE_REBUILD=1; shift ;;
    --shell)          OPEN_SHELL=1; shift ;;
    --build-dir)      BUILD_DIR="$2"; shift 2 ;;
    -h|--help)        usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or not on PATH." >&2
  exit 1
fi

image_exists() {
  docker image inspect "${IMAGE}" >/dev/null 2>&1
}

build_image() {
  local extra_args=()
  if [ "${FORCE_REBUILD:-0}" = "1" ]; then
    extra_args+=(--no-cache)
  fi
  echo "Building ${IMAGE} for ${PLATFORM}..."
  docker build \
    --platform "${PLATFORM}" \
    "${extra_args[@]}" \
    -f "${DOCKERFILE}" \
    -t "${IMAGE}" \
    "${REPO_ROOT}"
}

if [ "${BUILD_IMAGE_ONLY}" = "1" ]; then
  build_image
  echo "Image ready: ${IMAGE}"
  exit 0
fi

if [ "${FORCE_REBUILD}" = "1" ] || ! image_exists; then
  if [ "${FORCE_REBUILD}" = "1" ]; then
    echo "Rebuilding ${IMAGE} (no cache)..."
  else
    echo "Builder image ${IMAGE} not found; building it first..."
  fi
  build_image
fi

run_args=(
  --rm
  --platform "${PLATFORM}"
  -v "${REPO_ROOT}:/src:ro"
  -v "${BUILD_DIR}:/build"
  -e "HOMEUI_SRC=/src"
  -e "HOMEUI_BUILD=/build"
)

if [ "${OPEN_SHELL}" = "1" ]; then
  docker run -it "${run_args[@]}" --entrypoint bash "${IMAGE}"
  exit 0
fi

mkdir -p "${BUILD_DIR}"
docker run "${run_args[@]}" "${IMAGE}"

echo
echo "Raspberry Pi binary: ${BUILD_DIR}/homeui"
echo "Copy to the panel, e.g.:"
echo "  scp ${BUILD_DIR}/homeui pi@openhabian:/tmp/homeui"
echo "  ssh pi@openhabian 'sudo install -m 755 /tmp/homeui /usr/local/bin/homeui'"

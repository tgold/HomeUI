#!/usr/bin/env bash
set -euo pipefail

SRC="${HOMEUI_SRC:-/src}"
BUILD="${HOMEUI_BUILD:-/build}"
BUILD_TYPE="${HOMEUI_BUILD_TYPE:-Release}"

if [ ! -f "${SRC}/CMakeLists.txt" ]; then
  echo "Source tree not mounted at ${SRC} (missing CMakeLists.txt)." >&2
  exit 1
fi

mkdir -p "${BUILD}"

# Stale CMakeCache from before HOMEUI_NO_QML_CACHEGEN leaves qml AOT enabled and
# is a common reason cross-builds look "stuck" regenerating qmlcache/*.cpp.
if [ -f "${BUILD}/CMakeCache.txt" ] && ! grep -q 'HOMEUI_NO_QML_CACHEGEN:BOOL=ON' "${BUILD}/CMakeCache.txt" 2>/dev/null; then
  echo "==> Removing stale CMake cache (HOMEUI_NO_QML_CACHEGEN was not set)."
  rm -rf "${BUILD:?}"/*
fi

NPROC="$(nproc 2>/dev/null || echo 2)"
# Default 2 jobs: arm64-on-x86_64 under QEMU often segfaults g++ with -j>2.
# Override: HOMEUI_BUILD_JOBS=4 ./scripts/build-pi-docker.sh
# Apple Silicon (native arm64): HOMEUI_BUILD_JOBS="${NPROC}" is usually fine.
BUILD_JOBS="${HOMEUI_BUILD_JOBS:-2}"

echo "==> Configuring HomeUI (${BUILD_TYPE}, $(uname -m), container CPUs=${NPROC})..."
cmake -S "${SRC}" -B "${BUILD}" -G Ninja \
  -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
  -DHOMEUI_NO_QML_CACHEGEN=ON

echo "==> Building with -j${BUILD_JOBS} (set HOMEUI_BUILD_JOBS to change)..."
cmake --build "${BUILD}" -j"${BUILD_JOBS}"

echo "==> Done: ${BUILD}/homeui"
file "${BUILD}/homeui"

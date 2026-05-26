#!/usr/bin/env bash
set -euo pipefail

# --- Base build + Qt Quick runtime ----------------------------------------
sudo apt update
sudo apt install -y \
  g++ \
  git \
  ninja-build \
  cmake \
  pkg-config \
  qt6-base-dev \
  qt6-declarative-dev \
  qml6-module-qtquick \
  qml6-module-qtquick-controls \
  qml6-module-qtquick-templates \
  qml6-module-qtquick-layouts \
  qml6-module-qtquick-window \
  qml6-module-qtqml-workerscript

# --- MQTT integration (Milestone 4) ---------------------------------------
# Debian/Raspberry Pi OS does not ship the Qt MQTT add-on in its repos
# (no `qt6-mqtt-dev`).  We first try the package in case a backport exists,
# and otherwise build the matching `qtmqtt` source release against the
# system Qt installation.

install_qtmqtt_from_source() {
  local qt_version
  if command -v qmake6 >/dev/null 2>&1; then
    qt_version="$(qmake6 -query QT_VERSION 2>/dev/null || true)"
  fi
  if [ -z "${qt_version:-}" ]; then
    qt_version="$(dpkg-query -W -f='${Version}\n' qt6-base-dev 2>/dev/null | sed 's/+.*//;s/-.*//' || true)"
  fi
  if [ -z "${qt_version:-}" ]; then
    echo "Could not determine installed Qt 6 version - skipping qtmqtt build." >&2
    return 1
  fi

  echo "Building qtmqtt v${qt_version} from source to match the system Qt installation..."

  local workdir
  workdir="$(mktemp -d)"
  trap 'rm -rf "${workdir}"' RETURN

  if ! git clone --depth 1 --branch "v${qt_version}" \
        https://code.qt.io/qt/qtmqtt.git "${workdir}/qtmqtt"; then
    echo "Could not clone qtmqtt v${qt_version} (tag may not exist)." >&2
    echo "You can list available tags with:" >&2
    echo "  git ls-remote --tags https://code.qt.io/qt/qtmqtt.git" >&2
    return 1
  fi

  cmake -S "${workdir}/qtmqtt" -B "${workdir}/qtmqtt/build" \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release
  cmake --build "${workdir}/qtmqtt/build"
  sudo cmake --install "${workdir}/qtmqtt/build"
}

if sudo apt install -y qt6-mqtt-dev 2>/dev/null; then
  echo "Installed qt6-mqtt-dev from apt."
else
  echo "qt6-mqtt-dev not in apt repos - falling back to source build."
  if install_qtmqtt_from_source; then
    echo "qtmqtt built and installed - MQTT integration will be available."
  else
    echo "WARNING: qtmqtt could not be installed - MQTT integration will be disabled at build time." >&2
  fi
fi

echo "HomeUI Raspberry Pi build dependencies are installed."

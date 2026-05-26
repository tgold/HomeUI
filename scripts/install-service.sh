#!/usr/bin/env bash
#
# Install HomeUI as a kiosk service on Raspberry Pi OS / Debian.
#
# Default: install the user-level systemd service that auto-starts whenever
# the user logs in to a graphical session. Pass --system for a system-level
# service (KMS/EGLFS deployments) or --autostart for the XDG desktop entry.
#
set -euo pipefail

MODE="user"
SKIP_BUILD_INSTALL=0
BUILD_DIR="build-gcc"

usage() {
    cat <<EOF
Usage: $0 [--user|--system|--autostart] [--no-build-install] [--build-dir <dir>]

  --user            (default) install ~/.config/systemd/user/homeui.service
                    and enable it via systemctl --user.
  --system          install /etc/systemd/system/homeui.service for a
                    headless KMS/EGLFS kiosk image (runs as User=thomas).
  --autostart       install an XDG ~/.config/autostart/homeui.desktop entry
                    for desktop environments without a systemd graphical
                    user session (e.g. classic LXDE).
  --no-build-install
                    skip 'cmake --install' (assume the binary is already
                    in /usr/local/bin/homeui).
  --build-dir <dir> override CMake build directory (default 'build-gcc').
EOF
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --user)            MODE="user"; shift ;;
        --system)          MODE="system"; shift ;;
        --autostart)       MODE="autostart"; shift ;;
        --no-build-install) SKIP_BUILD_INSTALL=1; shift ;;
        --build-dir)       BUILD_DIR="$2"; shift 2 ;;
        -h|--help)         usage 0 ;;
        *) echo "Unknown option: $1" >&2; usage 1 ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Build artefacts ------------------------------------------------------
if [ "${SKIP_BUILD_INSTALL}" = "0" ]; then
    if [ ! -d "${REPO_ROOT}/${BUILD_DIR}" ]; then
        echo "Build directory '${BUILD_DIR}' not found. Configure and build first:" >&2
        echo "  cmake -S '${REPO_ROOT}' -B '${REPO_ROOT}/${BUILD_DIR}' -DCMAKE_CXX_COMPILER=g++" >&2
        echo "  cmake --build '${REPO_ROOT}/${BUILD_DIR}'" >&2
        exit 1
    fi
    echo "Installing homeui binary and default config via cmake --install..."
    sudo cmake --install "${REPO_ROOT}/${BUILD_DIR}" --prefix /usr/local
fi

if ! command -v /usr/local/bin/homeui >/dev/null 2>&1 \
        && [ ! -x /usr/local/bin/homeui ]; then
    echo "Warning: /usr/local/bin/homeui not found after install. Continuing anyway." >&2
fi

# --- Configuration --------------------------------------------------------
sudo mkdir -p /etc/homeui
if [ ! -f /etc/homeui/dashboard.json ]; then
    echo "Seeding /etc/homeui/dashboard.json from repo config/dashboard.json"
    sudo cp "${REPO_ROOT}/config/dashboard.json" /etc/homeui/dashboard.json
fi

case "${MODE}" in
    user)
        DEST="${HOME}/.config/systemd/user"
        mkdir -p "${DEST}"
        echo "Installing ${DEST}/homeui.service"
        cp "${REPO_ROOT}/packaging/systemd/homeui.service" "${DEST}/homeui.service"

        mkdir -p "${HOME}/.config/homeui"
        if [ ! -f "${HOME}/.config/homeui/env" ]; then
            cat <<'EOF' > "${HOME}/.config/homeui/env"
# HomeUI environment overrides. Uncomment + edit, then `systemctl --user restart homeui`.
#HOMEUI_OPENHAB_URL=http://openhabian:8080
#HOMEUI_OPENHAB_TOKEN=
#HOMEUI_MQTT_BROKER=mqtt://openhabian:1883
#HOMEUI_MQTT_USERNAME=panel
#HOMEUI_MQTT_PASSWORD=
#HOMEUI_MQTT_PANEL_ID=wallpanel-eg
#HOMEUI_BRIGHTNESS_PATH=/sys/class/backlight/10-0045/brightness
#HOMEUI_IDLE_TIMEOUT_MS=600000
#HOMEUI_LOG_LEVEL=info
EOF
            echo "Created ${HOME}/.config/homeui/env (edit to set OpenHAB/MQTT URLs etc.)"
        fi

        systemctl --user daemon-reload
        systemctl --user enable homeui.service

        # Make the service survive logout: lingering keeps user services alive
        # without an active login session.
        sudo loginctl enable-linger "${USER}"

        echo
        echo "User service installed and enabled. Start it now with:"
        echo "  systemctl --user start homeui.service"
        echo "  journalctl --user -u homeui -f"
        ;;

    system)
        echo "Installing /etc/systemd/system/homeui.service"
        sudo cp "${REPO_ROOT}/packaging/systemd/homeui-system.service" \
                /etc/systemd/system/homeui.service

        if [ ! -f /etc/homeui/env ]; then
            sudo tee /etc/homeui/env >/dev/null <<EOF
# HomeUI environment overrides for system service.
#HOMEUI_OPENHAB_URL=http://openhabian:8080
#HOMEUI_OPENHAB_TOKEN=
#HOMEUI_MQTT_BROKER=mqtt://openhabian:1883
#HOMEUI_MQTT_USERNAME=panel
#HOMEUI_MQTT_PASSWORD=
#HOMEUI_MQTT_PANEL_ID=wallpanel-eg
#HOMEUI_BRIGHTNESS_PATH=/sys/class/backlight/10-0045/brightness
#HOMEUI_IDLE_TIMEOUT_MS=600000
#HOMEUI_LOG_LEVEL=info
EOF
            echo "Created /etc/homeui/env (edit to set OpenHAB/MQTT URLs etc.)"
        fi

        sudo systemctl daemon-reload
        sudo systemctl enable homeui.service

        echo
        echo "System service installed and enabled. Start it now with:"
        echo "  sudo systemctl start homeui.service"
        echo "  journalctl -u homeui -f"
        ;;

    autostart)
        DEST="${HOME}/.config/autostart"
        mkdir -p "${DEST}"
        cp "${REPO_ROOT}/packaging/autostart/homeui.desktop" "${DEST}/homeui.desktop"
        echo "Installed ${DEST}/homeui.desktop"
        echo "Restart the desktop session to see HomeUI auto-start."
        ;;
esac

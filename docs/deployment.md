# Production deployment (Raspberry Pi)

Milestone 6 turns the dashboard into a kiosk-grade app that auto-starts on boot, dims the screen when nobody is in front of it, reloads its config on edit, and logs to the journal.

## TL;DR for a fresh Raspberry Pi OS install

```sh
git clone https://github.com/tgold/HomeUI.git
cd HomeUI
./scripts/install-pi-deps.sh         # compilers, Qt, qtmqtt
cmake -S . -B build-gcc -DCMAKE_CXX_COMPILER=g++
cmake --build build-gcc
./scripts/install-service.sh         # binary + /etc/homeui/dashboard.json + user service
systemctl --user start homeui.service
journalctl --user -u homeui -f
```

After this the dashboard restarts on every login (`loginctl enable-linger` keeps it alive without an interactive session) and respawns within five seconds of a crash.

## What `install-service.sh` does

By default (no flags), the script:

1. Runs `sudo cmake --install build-gcc --prefix /usr/local` to put the `homeui` binary in `/usr/local/bin/` and the seed `config/dashboard.json` in `/etc/homeui/`.
2. Copies `packaging/systemd/homeui.service` to `~/.config/systemd/user/`.
3. Seeds `~/.config/homeui/env` with commented-out `HOMEUI_*` overrides, ready for you to edit.
4. Runs `systemctl --user daemon-reload`, `systemctl --user enable homeui.service`, and `sudo loginctl enable-linger <you>`.

Flags:

- `--system`: install a system-level unit at `/etc/systemd/system/homeui.service` instead. Useful for headless EGLFS / KMS kiosk images that do not start a desktop session.
- `--desktop`: install `~/.local/share/applications/homeui.desktop` plus a Wayland-only autostart entry (`homeui-wayland.desktop` with `QT_QPA_PLATFORM=wayland`). Use this for labwc / wayfire kiosk images instead of the systemd user service.
- `--autostart`: drop a `~/.config/autostart/homeui.desktop` for desktop environments that ignore user systemd services (legacy LXDE setups).
- `--no-build-install`: skip the `cmake --install` step (use when you have already deployed the binary by other means, e.g. a fleet image).
- `--build-dir <dir>`: override the CMake build directory if you do not use `build-gcc`.

## Service control cheat sheet

```sh
systemctl --user start homeui.service
systemctl --user stop homeui.service
systemctl --user restart homeui.service
systemctl --user status homeui.service
journalctl --user -u homeui -f           # live log feed
journalctl --user -u homeui --since "1 hour ago"
```

For the system-level variant, drop `--user` and use `sudo`.

## Configuration sources

In order of precedence (most-specific wins):

1. Command-line flags (`--openhab-url`, `--mqtt-broker`, `--config`, `--idle-timeout`, `--log-level`, ...).
2. Environment variables loaded from `EnvironmentFile=-%h/.config/homeui/env` (or `/etc/homeui/env` for the system service).
3. Built-in defaults.

The relevant env vars are:

| Variable                       | Purpose                                                                 | Default                           |
|---                             |---                                                                      |---                                |
| `HOMEUI_CONFIG`                | Path to `dashboard.json`.                                               | `/etc/homeui/dashboard.json`      |
| `HOMEUI_OPENHAB_URL`           | OpenHAB base URL.                                                       | `http://openhab:8080`             |
| `HOMEUI_OPENHAB_TOKEN`         | OpenHAB API token.                                                      | unset                             |
| `HOMEUI_INFLUX_URL`            | InfluxDB base URL for irrigation history sparklines.                    | unset                             |
| `HOMEUI_INFLUX_TOKEN`          | InfluxDB **2.x** API token (read access to the bucket). When set, Flux v2 is used. | unset                |
| `HOMEUI_INFLUX_USER`           | InfluxDB **1.x** username (same as OpenHAB `influxdb.cfg` `user=`). Used when no token is set. | unset |
| `HOMEUI_INFLUX_PASSWORD`       | InfluxDB **1.x** password.                                              | unset                             |
| `HOMEUI_INFLUX_DATABASE`       | InfluxDB **1.x** database name (same as OpenHAB `db=`). If unset, `HOMEUI_INFLUX_BUCKET` or panel `history.bucket` is used. | unset |
| `HOMEUI_INFLUX_RETENTION_POLICY` | InfluxDB **1.x** retention policy (same as OpenHAB `retentionPolicy=`). Panel `history.retentionPolicy` overrides when set. | unset |
| `HOMEUI_INFLUX_ORG`            | InfluxDB **2.x** org (overrides panel `history.org` when set).          | unset                             |
| `HOMEUI_INFLUX_BUCKET`         | InfluxDB **2.x** bucket, or **1.x** database when no `HOMEUI_INFLUX_DATABASE`. | unset                      |
| `HOMEUI_MQTT_BROKER`           | `mqtt://host:port` (omit to disable).                                   | unset                             |
| `HOMEUI_MQTT_USERNAME`         | MQTT username.                                                          | unset                             |
| `HOMEUI_MQTT_PASSWORD`         | MQTT password.                                                          | unset                             |
| `HOMEUI_MQTT_CLIENT_ID`        | Override the auto-generated client id.                                  | `homeui-<host>-<pid>`             |
| `HOMEUI_MQTT_PANEL_ID`         | Panel id used in `home/panel/<id>/...` topics.                          | `main`                            |
| `HOMEUI_BRIGHTNESS_PATH`       | Backlight `brightness` sysfs node; set to `none` to force display power commands. | first `/sys/class/backlight/*` |
| `HOMEUI_DISPLAY_OFF_COMMAND`   | Command to turn the display fully off when brightness control is unavailable. | auto-detect `vcgencmd`/`xset` |
| `HOMEUI_DISPLAY_ON_COMMAND`    | Command to turn the display back on when brightness control is unavailable. | auto-detect `vcgencmd`/`xset`  |
| `HOMEUI_IDLE_TIMEOUT_MS`       | Idle timeout before the screen dims. `0` disables inactivity dimming.   | `600000` (10 min)                 |
| `HOMEUI_ACTIVE_BRIGHTNESS`     | Brightness percent restored on touch.                                   | `80`                              |
| `HOMEUI_IDLE_BRIGHTNESS`       | Brightness percent applied when idle.                                   | `0`                               |
| `HOMEUI_NIGHT_MODE_ENABLED`    | Enable the daily overnight screen-off window.                           | `true`                            |
| `HOMEUI_NIGHT_MODE_START`      | Time when the overnight screen-off starts.                              | `00:00`                           |
| `HOMEUI_NIGHT_MODE_END`        | Time when the screen turns back on.                                     | `06:30`                           |
| `HOMEUI_LOG_LEVEL`             | One of `debug`, `info`, `warning`, `error`.                             | `info`                            |

## Logging

`main.cpp` installs a friendly default `qSetMessagePattern` of:

```
[2026-05-26 11:54:01.123] homeui.main info: HomeUI starting (Qt 6.4.2, log level info)
```

`HOMEUI_LOG_LEVEL` maps to Qt's `QLoggingCategory::setFilterRules` for the `homeui.*` categories. For finer-grained control (e.g. enabling Qt's own networking traces) you can still set `QT_LOGGING_RULES` explicitly via the systemd unit's `Environment=` lines.

The current categories are:

- `homeui.main`  - startup + lifecycle
- `homeui.config` - dashboard config loading / file watcher
- `homeui.brightness` - backlight writes
- `homeui.idle` - sleep / wake transitions
- `homeui.mjpeg` - camera stream connect / disconnect / errors
- (`homeui.mqtt` is owned by MqttClient if compiled in)

## Reconnect behaviour

The OpenHAB and MQTT clients already self-heal on disconnect (event stream reconnect after 5 s, MQTT keep-alive + reconnect timer). When the screen wakes from idle, no extra work is needed: both connections stay alive while the backlight is off because we keep the Qt event loop running.

## Config reload

Three independent triggers will re-read `dashboard.json`:

1. **File watcher** (default on) - the app watches the config file *and* its parent directory and reloads after a 250 ms debounce when either changes. Disable with `--no-watch-config` or by setting up the watcher manually via QML.
2. **MQTT control plane** - publishing anything to `home/panel/<panel-id>/reload` triggers an immediate `dashboardConfig.reload()`.
3. **In-app button** - the validation error banner has a "Reload config" button for hands-on debugging when the dashboard fails to load.

The visible UI is rebuilt automatically when `pages` changes (the `Repeater` in `qml/Main.qml` is bound to `dashboardConfig.pages`).

## Brightness and screen idle

The `ScreenIdleController` installs a Qt event filter that resets a single-shot timer on every mouse / touch / wheel / key / tablet event. When the timer fires (`idle-timeout` / `HOMEUI_IDLE_TIMEOUT_MS` milliseconds of inactivity), it emits `brightnessRequested(idleBrightness)`, which the same backlight helper that handles MQTT writes consumes. The first event after going idle wakes the screen back to `activeBrightness`.

It also enforces a daily overnight screen-off window. By default the panel switches to `idleBrightness` at `00:00` and restores `activeBrightness` at `06:30`. Touch input does not wake the panel during this scheduled window.

Settings:

- `HOMEUI_IDLE_TIMEOUT_MS=0` - disable inactivity dimming while keeping the scheduled night window.
- `HOMEUI_ACTIVE_BRIGHTNESS=70` - dim the wake-up brightness.
- `HOMEUI_IDLE_BRIGHTNESS=5` - keep the screen lit at a low level instead of fully off (useful if the LCD does not like being driven to 0).
- `HOMEUI_NIGHT_MODE_ENABLED=false` or `--no-night-mode` - disable the overnight screen-off window.
- `HOMEUI_NIGHT_MODE_START=23:00` and `HOMEUI_NIGHT_MODE_END=06:30` - customize the quiet-hours window.
- `HOMEUI_BRIGHTNESS_PATH=none`, `HOMEUI_DISPLAY_OFF_COMMAND='vcgencmd display_power 0'`, and `HOMEUI_DISPLAY_ON_COMMAND='vcgencmd display_power 1'` - force full display power switching on hardware without usable `/sys/class/backlight` brightness control. When display commands are unset, HomeUI tries `vcgencmd` first and then `xset dpms force off/on`.
- MQTT topic `home/panel/<id>/brightness/set` (0..100) overrides `activeBrightness` for the rest of the session - useful for ambient-light or scene automation in OpenHAB.

For the kiosk to actually be able to write to `/sys/class/backlight/*/brightness`, your user needs write access to that file. On standard Raspberry Pi OS the `video` group already has it; if your distribution doesn't, add a udev rule:

```sh
sudo tee /etc/udev/rules.d/99-backlight.rules >/dev/null <<'EOF'
SUBSYSTEM=="backlight", ACTION=="add", \
  RUN+="/bin/chmod 0664 /sys%p/brightness", \
  RUN+="/bin/chgrp video /sys%p/brightness"
EOF
sudo udevadm control --reload
sudo udevadm trigger
sudo usermod -a -G video $USER
```

Re-login (or reboot) for the group change to apply.

## Wayland vs. X11 vs. EGLFS

- **Raspberry Pi OS Bookworm (default X11)**: nothing to do, the user service inherits the session.
- **Wayland (labwc / wayfire)**: install `qt6-wayland` so the QPA plugin is available, then deploy with `./scripts/install-service.sh --desktop` so the launcher and session autostart are installed. `cmake --install` also drops `/usr/local/share/applications/homeui.desktop` for system-wide menus.
- **Headless kiosk (no desktop session)**: use `--system` to install `homeui-system.service`, which already sets `QT_QPA_PLATFORM=eglfs` and an explicit `XDG_RUNTIME_DIR`. You will also need `sudo apt install qt6-base-private-dev libgles2-mesa libinput-bin` and the touchscreen device exposed to the service user.

## Updating in place

```sh
cd ~/HomeUI
git pull
cmake --build build-gcc
sudo cmake --install build-gcc --prefix /usr/local
systemctl --user restart homeui.service
```

The `install-service.sh` script only needs to be re-run when the service file itself changes (very rarely).

### Building on a workstation (Docker)

From a Mac or Linux machine with Docker, cross-build for Debian 13 (trixie) arm64 without a native Qt toolchain:

```sh
./scripts/build-pi-docker.sh
scp build-pi-docker/homeui pi@your-panel:/tmp/homeui
ssh pi@your-panel 'sudo install -m 755 /tmp/homeui /usr/local/bin/homeui && systemctl --user restart homeui.service'
```

See `README.md` for image rebuild and debug shell options.

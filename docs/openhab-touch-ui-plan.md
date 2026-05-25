# OpenHAB Touchscreen UI Project Plan

## Goals

Build a native touchscreen dashboard for OpenHAB that runs on a Raspberry Pi with an approximately 10-inch display. The app should replace or complement an existing HABPanel-style UI with a faster, native, configurable interface that supports direct MQTT integration and efficient OpenHAB communication.

## Requirements

- Run on Raspberry Pi hardware with a roughly 10-inch touchscreen.
- Be a native application so it can integrate directly with MQTT.
- Connect to the OpenHAB server using an efficient protocol for live updates and commands.
- Provide a multi-page swipeable layout.
- Support configurable panels for common home automation functionality.
- Use the existing HABPanel dashboard as the layout reference: dark theme, compact room panels, status tiles, energy widgets, and camera content.

## Recommended Technology

Use Qt 6 with QML for the native application.

Reasons:

- Good support for Raspberry Pi and Linux touchscreen devices.
- Native fullscreen/kiosk deployment without a browser shell.
- Hardware-accelerated UI suitable for a wall-mounted dashboard.
- Strong declarative UI model for reusable home automation widgets.
- Built-in or well-supported integrations for HTTP, WebSockets, and MQTT.
- Mature systemd deployment model on Raspberry Pi OS.

## Target Architecture

```text
Raspberry Pi Touch App
|
+-- UI Layer
|   +-- Swipeable pages
|   +-- Configurable panels
|   +-- Room dashboards
|   +-- Camera widgets
|   +-- Status and navigation bar
|
+-- OpenHAB Integration
|   +-- REST API for commands and initial state
|   +-- Event stream or WebSocket for live item updates
|
+-- MQTT Integration
|   +-- Subscribe to custom topics
|   +-- Publish commands, events, and panel status
|   +-- Optional local device control
|
+-- Configuration Layer
|   +-- YAML or JSON dashboard configuration
|   +-- Panel definitions
|   +-- OpenHAB item mappings
|   +-- MQTT topic mappings
|
+-- Runtime Layer
    +-- Fullscreen kiosk mode
    +-- systemd auto-start
    +-- Offline and reconnect handling
    +-- Logging and diagnostics
```

## OpenHAB Communication

Use a hybrid OpenHAB client:

1. REST API for:
   - Loading initial item states.
   - Sending commands to items.
   - Reading item labels, metadata, persistence values, and optional thing information.
2. OpenHAB event stream or WebSocket-style event API for:
   - Live item state changes.
   - Avoiding constant polling.
   - Keeping dashboard widgets up to date with low latency.

This keeps the UI responsive while minimizing repeated HTTP polling.

## MQTT Integration

The app should connect directly to the MQTT broker, likely the same broker used by OpenHAB.

Use MQTT for:

- Custom sensors.
- Device health and status.
- Local automation shortcuts.
- Non-OpenHAB devices.
- Dashboard heartbeat/status messages.
- Screen brightness, wake, sleep, or page-control commands.

Example dashboard topics:

```text
home/panel/main/status
home/panel/main/brightness/set
home/panel/main/page/set
home/panel/main/reload
```

Example status payload:

```json
{
  "online": true,
  "page": "ground_floor",
  "brightness": 80,
  "openhabConnected": true,
  "mqttConnected": true
}
```

## UI Concept

The UI should follow the existing HABPanel reference:

- Dark theme.
- Top status bar with OpenHAB status, time, connection icons, and mode indicators.
- Compact room and function panels.
- Orange/blue button states similar to the current UI.
- Optional camera tile in the lower center area.
- Energy/status widgets on the right.
- Horizontal page swiping for navigation.

Suggested pages:

1. Overview
   - House mode.
   - Frequently used lights.
   - Temperature summary.
   - Security/camera tile.
   - Energy summary.
2. Ground floor
   - Living room.
   - Dining room.
   - Kitchen.
   - Terrace controls.
3. Climate
   - Room temperatures.
   - Thermostats.
   - Humidity.
   - Heating/cooling mode.
4. Shutters and blinds
   - Per-room roller controls.
   - Group controls.
   - Position sliders.
5. Energy
   - PV production.
   - Grid import/export.
   - Battery status.
   - Consumption.
   - Water or heat usage.
6. Security
   - Cameras.
   - Doors and windows.
   - Alarm state.
   - Presence.

## Configurable Panel System

The dashboard should be driven by local configuration rather than hard-coded rooms and items.

Example YAML-style configuration:

```yaml
pages:
  - id: overview
    title: Overview
    panels:
      - type: room
        title: Wohnzimmer
        items:
          - type: temperature
            item: Wohnzimmer_Temperatur
          - type: switch
            label: Licht
            item: Wohnzimmer_Licht
          - type: rollershutter
            label: Rollo
            item: Wohnzimmer_Rollo

      - type: energy
        title: Energie
        items:
          - label: PV Erzeugung
            item: PV_Power
          - label: Netz
            item: Grid_Power
          - label: Batterie
            item: Battery_Level

      - type: camera
        title: Einfahrt
        url: rtsp://camera.local/stream
```

Recommended panel types:

- Switch.
- Dimmer.
- Color light.
- Thermostat.
- Temperature display.
- Humidity display.
- Roller shutter/blind.
- Scene button.
- Camera feed.
- Energy meter.
- Presence/security sensor.
- Custom MQTT tile.
- Grouped room tile.

## Core Modules

### OpenHAB Client

- Authenticate with OpenHAB.
- Fetch item states.
- Send commands.
- Subscribe to item state updates.
- Handle reconnects and stale values.

### MQTT Client

- Connect to the configured broker.
- Subscribe to configured topics.
- Publish app status and commands.
- Power MQTT-backed widgets.

### Dashboard Config Loader

- Parse YAML or JSON config.
- Validate pages, panels, and item references.
- Expose configuration to QML.
- Support manual or MQTT-triggered config reload if practical.

### UI Component Library

Reusable QML components:

- `SwitchTile`
- `DimmerTile`
- `RollerTile`
- `ThermostatTile`
- `EnergyTile`
- `CameraTile`
- `SceneButton`
- `RoomPanel`
- `StatusBar`
- `SwipePageContainer`

### State Store

Maintain central runtime state for:

- OpenHAB item states.
- MQTT values.
- Connection status.
- Current page.
- Theme.
- Pending commands.
- Stale data indicators.

## Raspberry Pi Deployment

Recommended target:

- Raspberry Pi 4 or Raspberry Pi 5.
- Raspberry Pi OS 64-bit.
- 10-inch touchscreen, likely 1280x800 or similar.
- Fullscreen app launched by systemd.
- Automatic restart on crash.
- Disabled screen blanking for wall-panel use, unless sleep/wake behavior is added.
- Config stored under a path such as:

```text
/etc/openhab-touch-panel/config.yaml
```

Startup flow:

1. Boot Raspberry Pi.
2. Start native dashboard service.
3. Load local config.
4. Connect to MQTT broker.
5. Connect to OpenHAB.
6. Load initial item states.
7. Subscribe to live updates.
8. Show fullscreen dashboard.

## Suggested Implementation Milestones

### Milestone 1: Prototype Shell

- Qt/QML fullscreen app.
- Dark theme.
- Swipeable multi-page layout.
- Static mock panels based on the current HABPanel layout.

### Milestone 2: OpenHAB Connection

- REST connection.
- Fetch item states.
- Send commands.
- Live item updates through event stream or WebSocket.

### Milestone 3: Configurable Dashboard

- YAML or JSON config.
- Dynamically generated pages.
- Reusable panel components.
- Config validation with useful error messages.

### Milestone 4: MQTT Integration

- Broker connection.
- Subscribe and publish support.
- MQTT-backed widgets.
- App heartbeat/status topic.

### Milestone 5: Home Automation Widgets

- Lights.
- Dimmers.
- Roller shutters.
- Thermostats.
- Scenes.
- Energy.
- Camera.

### Milestone 6: Production Raspberry Pi Mode

- systemd service.
- Fullscreen autostart.
- Reconnect handling.
- Logging.
- Config reload.
- Brightness and sleep behavior.

## Recommended MVP

The first usable version should include:

- Fullscreen native Qt app.
- Three swipeable pages.
- OpenHAB REST commands.
- Live OpenHAB item updates.
- MQTT connection.
- Configurable YAML or JSON layout.
- Panels for lights, roller shutters, temperature, energy, and camera.
- Automatic startup on Raspberry Pi.

This provides a solid native replacement foundation for the HABPanel UI while keeping the layout familiar.

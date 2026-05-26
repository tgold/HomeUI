# Dashboard Configuration

Milestone 3 moves the dashboard layout out of `qml/Main.qml` and into JSON.

Default lookup order:

1. `HOMEUI_CONFIG`
2. `./config/dashboard.json`
3. `../config/dashboard.json` relative to the executable directory
4. `/etc/homeui/dashboard.json`

You can also pass a path explicitly:

```sh
./build-gcc/homeui --config /path/to/dashboard.json
```

## Root object

```json
{
  "pages": []
}
```

`pages` must be a non-empty array.

## Page layouts

### Columns layout

Use this for HABPanel-style dashboards with vertical stacks of panels.

```json
{
  "id": "ground-floor",
  "title": "RAUME EG",
  "layout": "columns",
  "columns": [
    {
      "width": 292,
      "panels": []
    },
    {
      "fillWidth": true,
      "panels": []
    }
  ]
}
```

### Grid layout

Use this for evenly distributed room pages.

```json
{
  "id": "climate",
  "title": "KLIMA",
  "layout": "grid",
  "columns": 3,
  "panels": []
}
```

## Panel types

Supported panel types:

- `room`
- `energy`
- `camera`
- `mode`
- `controls`
- `mqtt`

### Room panel

```json
{
  "type": "room",
  "title": "Wohnzimmer",
  "subtitle": "Licht, Hue, Rollo",
  "fallback": {
    "temperature": "24.9 C",
    "humidity": "45 %",
    "lightOn": true,
    "shutterClosed": false,
    "shutterPosition": "30 %"
  },
  "items": {
    "temperature": "Wohnzimmer_Temperatur",
    "humidity": "Wohnzimmer_Luftfeuchtigkeit",
    "light": "Wohnzimmer_Licht",
    "hue": "Wohnzimmer_Hue",
    "shutter": "Wohnzimmer_Rollo"
  }
}
```

### Energy panel

```json
{
  "type": "energy",
  "title": "Energie",
  "items": {
    "pv": "PV_Power",
    "grid": "Grid_Power",
    "consumption": "House_Power",
    "battery": "Battery_Level",
    "water": "Water_Today"
  }
}
```

### Camera panel

Milestone 3 still renders a static camera placeholder. The config already carries the display metadata needed by later camera work.

```json
{
  "type": "camera",
  "title": "Security Kamera",
  "location": "Carport",
  "fillHeight": true
}
```

### Mode panel

```json
{
  "type": "mode"
}
```

### Controls panel

```json
{
  "type": "controls",
  "title": "Security",
  "tilesPerRow": 4,
  "controls": [
    {
      "label": "Alarm",
      "value": "HOME",
      "secondary": "armed night",
      "iconText": "S",
      "accentColor": "#ef4444",
      "item": "Alarm_Mode",
      "onCommand": "HOME",
      "offCommand": "OFF"
    }
  ]
}
```

Layout options:

- `tilesPerRow` (default `0` = auto) - force a specific tile-per-row count. With the default the panel computes how many fit at `minTileWidth` (default `140` px) and wraps to additional rows as needed, so the panel grows vertically rather than squashing tiles.
- `minTileWidth` (default `140`) - minimum tile width used by the auto layout.

If `command` is provided, the control always sends that command. Otherwise it toggles between `onCommand` and `offCommand`.

### Control widget kinds (milestone 5)

Every entry in `controls` may declare a `kind` that selects a specialised home automation widget. Without `kind` (or with `kind: "switch"`) the existing toggle tile is rendered.

Supported kinds: `switch`, `dimmer`, `shutter`, `thermostat`, `scene`.

#### Dimmer (`kind: "dimmer"`)

Renders a slider 0..100 plus a power icon that toggles between `0` and `onLevel`.

```json
{
  "kind": "dimmer",
  "label": "Wohnzimmer",
  "iconText": "L",
  "item": "GF_LivingRoom_Light_Dimmer",
  "min": 0,
  "max": 100,
  "onLevel": 80
}
```

- `min` / `max` (defaults `0` / `100`) - slider range.
- `onLevel` (default `max`) - value sent when the icon is tapped to turn the dimmer on.
- The slider sends the new integer value as a numeric command when released.

#### Shutter (`kind: "shutter"`)

Renders three press buttons (UP / STOP / DOWN) plus a textual position readout. Reads the rollershutter state to detect open/closed.

```json
{
  "kind": "shutter",
  "label": "Wohnzimmer",
  "item": "GF_LivingRoom_Shutter",
  "upCommand": "UP",
  "stopCommand": "STOP",
  "downCommand": "DOWN"
}
```

`upCommand`, `stopCommand`, and `downCommand` default to `UP`, `STOP`, `DOWN`.

#### Thermostat (`kind: "thermostat"`)

Renders a setpoint readout with `-` / `+` buttons. Optionally shows a separate live current temperature.

```json
{
  "kind": "thermostat",
  "label": "Wohnzimmer",
  "item": "GF_LivingRoom_Setpoint",
  "currentItem": "GF_LivingRoom_Temperature",
  "step": 0.5,
  "min": 5,
  "max": 30
}
```

- `item` - the setpoint item, updated by the `-` / `+` buttons.
- `currentItem` - optional, displayed in the header.
- `step` (default `0.5`), `min` (default `5`), `max` (default `30`) - bounds for the setpoint.

#### Scene (`kind: "scene"`)

Renders a wide push button styled with the accent colour. Best for one-shot triggers (scenes, doorbell pushes, alarm scenes).

```json
{
  "kind": "scene",
  "label": "Alle Rollos hoch",
  "iconText": "U",
  "accentColor": "#22c55e",
  "item": "GF_Shutter_Scene",
  "command": "FULLUP"
}
```

Falls back to `mqttPayload` (or `"ON"`) when no `command` is set.

### MQTT-backed controls

A control can also be backed by an MQTT topic instead of an OpenHAB item:

```json
{
  "label": "Garage Tor",
  "iconText": "G",
  "accentColor": "#38bdf8",
  "mqttTopic": "home/garage/door/state",
  "mqttOnPayload": "OPEN",
  "mqttOffPayload": "CLOSE",
  "mqttQos": 1,
  "mqttRetain": false
}
```

- `mqttTopic` - the topic the tile shows the value of and publishes on click.
- `mqttPayload` - if set, publishes this payload verbatim on every click (no toggling).
- `mqttOnPayload` / `mqttOffPayload` - payloads sent when the current value is off / on, respectively. Fall back to `onCommand` / `offCommand` and finally `"ON"` / `"OFF"`.
- `mqttQos` (default `0`) and `mqttRetain` (default `false`) - QoS level and retain flag for the published message.

### MQTT panel

A read-only display of one or more MQTT topics:

```json
{
  "type": "mqtt",
  "title": "Wetterstation",
  "items": [
    {
      "label": "Wind",
      "topic": "home/weather/wind",
      "fallback": "-- km/h",
      "detail": "10 min avg"
    },
    {
      "label": "Regen",
      "topic": "home/weather/rain",
      "warning": true
    }
  ]
}
```

Each entry takes `label`, `topic`, optional `fallback`, `detail`, and `warning`. Numeric payloads are auto-formatted (units preserved, fractions in `0..1` rendered as percent). Non-numeric payloads pass through verbatim.

## MQTT integration (milestone 4)

The app connects to an MQTT broker for two purposes:

1. **App heartbeat / control plane.** On connect the app publishes a retained status payload to `home/panel/<panel-id>/status`, for example:

```json
{ "online": true, "page": "uebersicht", "openhabConnected": true, "mqttConnected": true }
```

The same topic carries `{ "online": false }` as the MQTT Last Will, so the broker reports the panel offline as soon as the TCP connection drops.

The app also subscribes to three control topics:

| Topic | Payload | Effect |
|---|---|---|
| `home/panel/<panel-id>/page/set` | page index or `id`/`title` | switch the visible page |
| `home/panel/<panel-id>/brightness/set` | 0..100 | write the value (scaled to the device range) to `/sys/class/backlight/*/brightness` |
| `home/panel/<panel-id>/reload` | any | reload `dashboard.json` |

2. **MQTT-backed widgets.** Any `controls` tile can replace its OpenHAB binding with an MQTT topic (see schema above) and the `mqtt` panel type renders read-only MQTT topics directly.

Configuration:

```sh
HOMEUI_MQTT_BROKER=mqtt://openhabian:1883 \
HOMEUI_MQTT_USERNAME=panel HOMEUI_MQTT_PASSWORD=secret \
HOMEUI_MQTT_PANEL_ID=wallpanel-eg \
./build-gcc/homeui

./build-gcc/homeui \
  --mqtt-broker mqtt://openhabian:1883 \
  --mqtt-username panel --mqtt-password secret \
  --mqtt-panel-id wallpanel-eg

./build-gcc/homeui --no-mqtt
```

If `Qt6::Mqtt` is not available at build time the MQTT module is silently dropped and the `--mqtt-*` options become no-ops.

## Validation

The app validates the JSON at startup. If validation fails, the UI displays the validation error and offers a reload button.

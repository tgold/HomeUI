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

Use this for evenly distributed room pages. All cells in a grid row are stretched to match the tallest cell.

```json
{
  "id": "climate",
  "title": "KLIMA",
  "layout": "grid",
  "columns": 3,
  "panels": []
}
```

### Masonry layout

Pinterest-style packing: each panel keeps its natural height, and new panels drop into the column with the smallest current height. This is the right pick when panels have very different sizes (e.g. an overview page mixing a tall Wohnzimmer card with a short Robi tile) so short tiles do not get stretched to match tall neighbours.

```json
{
  "id": "overview",
  "title": "UEBERSICHT",
  "layout": "masonry",
  "columns": 3,
  "columnWidth": 320,
  "panels": []
}
```

- `columns` (optional) - explicit column count. When omitted the layout derives a count from the available width and `columnWidth`.
- `columnWidth` (optional, default `320`) - target column width used by the auto column count.
- Panels accept `columnSpan` so a full-width footer (e.g. a Sonos player) can stretch across all columns. A spanning panel is placed below the tallest column at the time of placement, then all columns advance to its bottom edge.

## Panel types

Supported panel types:

- `room`
- `energy`
- `camera`
- `mode`
- `controls`
- `mqtt`
- `sonos`

Grid pages also accept `columnSpan` / `rowSpan` on any panel to make it stretch over multiple cells (e.g. a full-width Sonos footer below a 3-column overview).

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
    "battery": "Battery_Level"
  }
}
```

### Camera panel

Renders a live camera feed inside the dashboard tile. The actual rendering mode is picked automatically:

- `streamUrl` set -> live **MJPEG** stream via the built-in `MjpegView` (no external video stack required).
- `snapshotUrl` set -> periodic **JPEG snapshot** polling (refresh every `refreshInterval` ms).
- Neither set -> the original static placeholder (useful while wiring up a new dashboard).

```json
{
  "type": "camera",
  "title": "Tuerklingel",
  "location": "Einfahrt",
  "streamUrl": "http://192.168.0.23:5000/webapi/entry.cgi?api=SYNO.SurveillanceStation.Stream.VideoStreaming&version=1&method=Stream&format=mjpeg&cameraId=2&StmKey=%22b9ff7f89f0b9be9b8971831856023748%22",
  "snapshotUrl": "http://192.168.0.23:5000/webapi/entry.cgi?api=SYNO.SurveillanceStation.SnapShot&version=1&method=TakeSnapshot&cameraId=2&StmKey=%22b9ff7f89f0b9be9b8971831856023748%22",
  "format": "mjpeg",
  "refreshInterval": 1000,
  "ignoreSslErrors": false,
  "height": 260
}
```

Fields:

- `streamUrl` - HTTP URL to a `multipart/x-mixed-replace` MJPEG stream. The tile auto-reconnects on transport errors (`reconnectInterval` 3 s by default).
- `snapshotUrl` - URL that returns a single JPEG each call. Used as the visible source when `format` is `"snapshot"`.
- `format` (optional) - explicit override of `mjpeg`, `snapshot`, or `placeholder`. Detection from `streamUrl` / `snapshotUrl` is fine for most cases; only set this if you want to force one path.
- `refreshInterval` (default `1000`) - milliseconds between snapshot polls. Minimum 250.
- `ignoreSslErrors` (default `false`) - accept self-signed certificates on `https://`-based Synology hosts.
- `location`, `height`, `title` - cosmetic.

#### Synology Surveillance Station formats

The URL the user provided uses Synology's `SYNO.SurveillanceStation.Stream.VideoStreaming` API. The streaming format is selected with the `format=` query parameter. Trade-offs:

| Format         | URL `format=` | How HomeUI renders it       | Pros                                                                 | Cons                                                                  |
|---             |---            |---                          |---                                                                   |---                                                                    |
| MJPEG          | `mjpeg`       | `MjpegView` (built-in)      | No extra deps; works on any Pi; smooth ~10-25 fps; lowest latency.   | High bandwidth (~1-3 Mbit/s @ 720p); JPEG decode is per-frame.        |
| MXPEG          | `mxpeg`       | not supported               | Only relevant for Mobotix cameras.                                   | Custom decoder not bundled.                                           |
| Snapshot       | n/a (`SYNO.SurveillanceStation.SnapShot.TakeSnapshot`) | `Image` polling | Easiest on the broker/Pi; works behind any reverse proxy.            | Not real-time; visible refresh at the poll rate.                      |
| H.264 / RTSP   | n/a (separate URL via camera or Surveillance Station's RTSP profile) | requires QtMultimedia + GStreamer build | Smallest bandwidth; HW decode on Pi.                                 | Adds GStreamer dependency; not yet wired by default in this repo.     |

For a Pi 4/5 wall panel and the Surveillance Station MJPEG stream the user pasted, **`format=mjpeg`** is the right pick - it's what is currently implemented and gives the smoothest result without pulling in a video stack. Use a snapshot URL only when bandwidth is constrained or when the panel idles for long periods.

A future milestone can add an RTSP / H.264 path through `QtMultimedia`; the panel schema is already shaped for that (just add `format: "rtsp"` plus a `streamUrl: "rtsp://..."`).

#### Synology `StmKey` notes

The `StmKey` value must be wrapped in double quotes when sent to Synology. In URLs the quotes are URL-encoded as `%22`, so the example above keeps them as `%22b9ff...%22`. Equivalently you can write the JSON value with escaped quotes: `"StmKey=\"b9ff...\""`. Either form works.

You typically obtain the `StmKey` by logging into Surveillance Station and reading the `Stream-Key` from the camera details page, or by calling `SYNO.SurveillanceStation.Stream.AcquireStreamKey`.

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

### Control widget kinds

Every entry in `controls` may declare a `kind` that selects a specialised home automation widget. Without `kind` (or with `kind: "switch"`) the existing toggle tile is rendered.

Supported kinds: `switch`, `dimmer`, `color`, `shutter`, `thermostat`, `scene`, `progress` (alias `gauge`), `selector`, `dropdown`, `value`.

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

#### Color (`kind: "color"`)

Hue + brightness picker for OpenHAB `Color` items. Renders a horizontal hue gradient strip with a draggable marker, a brightness slider, and a circular power button whose fill reflects the current colour.

```json
{
  "kind": "color",
  "label": "Wohnzimmer Hue",
  "iconText": "H",
  "accentColor": "#fbbf24",
  "item": "GF_LivingRoom_Light_Color"
}
```

State / command encoding:

- The tile expects the OpenHAB Color state in the standard `"H,S,B"` form (hue 0..360, saturation 0..100, brightness 0..100). Plain numeric / `ON` / `OFF` states are also tolerated so this kind degrades cleanly when bound to a `Dimmer` or `Switch` item.
- Hue strip releases publish a full `"H,S,B"` command, preserving the current saturation (defaults to `100` when off) and brightness (defaults to `100` when off).
- The brightness slider publishes the raw integer percentage on release, which OpenHAB treats as a `PercentType` command on `Color` items - hue and saturation are kept.
- The power button publishes `ON` / `OFF`.

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

`upCommand`, `stopCommand`, and `downCommand` default to `UP`, `STOP`, `DOWN`. The state parser also understands `OPEN` / `CLOSED`, `ON` / `OFF`, and the `FULLUP` / `HALFDOWN` / `FULLDOWN` / `FULLSTOP` scene strings produced by some KNX setups.

If the visible state lives on a different OpenHAB item than the one that accepts movement commands (e.g. a `Switch` status item alongside a sibling `*_Scene` `String` item), set `commandItem` to the command target. The widget then reads state from `item` but sends `upCommand` / `stopCommand` / `downCommand` to `commandItem`. Set `hideStop: true` to remove the stop button (useful for plain 2-state `Switch` items).

```json
{
  "kind": "shutter",
  "label": "Wohnzimmer",
  "item": "GF_LivingRoom_Shutter",
  "commandItem": "GF_LivingRoom_Shutter_Scene",
  "upCommand": "FULLUP",
  "stopCommand": "FULLSTOP",
  "downCommand": "FULLDOWN"
}
```

`commandItem` works the same way for any other control kind — its presence routes the OpenHAB `POST` to that item instead of `item`. For MQTT-backed tiles the equivalent is `commandTopic`.

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

#### Progress / gauge (`kind: "progress"` or `"gauge"`)

Renders a read-only horizontal progress bar with a numeric value on the right. Useful for cistern level, NAS volume usage, battery SoCs etc.

```json
{
  "kind": "progress",
  "label": "Zisterne",
  "accentColor": "#22c55e",
  "item": "zisterne_fuellstand",
  "min": 0,
  "max": 100,
  "unit": "%",
  "decimals": 0
}
```

- `min` / `max` (default `0` / `100`) define the bar range.
- `unit` overrides the displayed unit; when empty the unit baked into the OpenHAB state is preserved.
- `decimals` controls the displayed precision (defaults: `0` for `%`/`W`, `1` otherwise).

#### Selector (`kind: "selector"`)

Renders a compact row of radio-style buttons for picking one of a fixed set of states (e.g. EVCC mode, robot vacuum command, scene shortcuts).

```json
{
  "kind": "selector",
  "label": "Modus",
  "item": "evcc_loadpoint0_mode",
  "accentColor": "#f59e0b",
  "options": [
    { "label": "PV",   "value": "pv" },
    { "label": "Min",  "value": "minpv" },
    { "label": "Fast", "value": "now" },
    { "label": "Off",  "value": "off" }
  ]
}
```

`options` is required and must contain at least one `{ label, value }` pair. The currently active value is highlighted by string-comparing it against the item state (case-insensitive). Each press dispatches `value` as the command (OpenHAB or MQTT, depending on which binding the control declares).

#### Dropdown (`kind: "dropdown"`)

Renders a compact ComboBox-style picker. Same shape as `selector` but with the options hidden behind a popup, which scales nicely past 4-5 entries (e.g. a heat pump mode list, Lüftungsstufe 0/1/2/3, EVCC target hours).

```json
{
  "kind": "dropdown",
  "label": "Waermepumpe Betriebsart",
  "item": "thz_betriebsart_string",
  "accentColor": "#f59e0b",
  "options": [
    { "label": "Automatik",   "value": 11 },
    { "label": "Warmwasser",  "value": 5 },
    { "label": "Handbetrieb", "value": 14 },
    { "label": "Notbetrieb",  "value": 0 },
    { "label": "Bereitschaft","value": 1 },
    { "label": "Tagbetrieb",  "value": 3 },
    { "label": "Abwesenheit", "value": 4 }
  ]
}
```

- `options` is required (same format as `selector`) and must contain at least one entry. Values may be strings or numbers - they are compared numerically when both sides parse as numbers, otherwise case-insensitively.
- The currently active label is shown in the closed combobox. While the popup is open, live state updates do not yank the selection.
- Picking an entry dispatches its `value` as the command (OpenHAB or MQTT).

#### Value (`kind: "value"`)

Read-only display tile. Renders the OpenHAB / MQTT state with the standard formatter but never sends a command on tap. Useful for status fields such as Fritzbox uptime, current weather condition, or sun azimuth.

```json
{
  "kind": "value",
  "format": "temperature",
  "label": "Temperatur",
  "iconText": "T",
  "accentColor": "#f97316",
  "item": "GF_LivingRoom_Temperature"
}
```

Optional formatting hints (also honoured by the `progress` tile):

- `format` - one of `temperature` (1 decimal + `°C`), `humidity` (0 decimals + `%`), `power` (0 decimals + `W`), `energy` (2 decimals + `kWh`), `fraction` (0..1 scaled to %). When set, `decimals` overrides the default precision.
- `unit` - manual unit suffix (used when the OpenHAB state has no unit). Combine with `decimals` to control precision.
- `decimals` - explicit decimal-place count.
- `scale` - multiplier applied to the numeric value before formatting (e.g. `0.001` to render `Wh` items as `kWh`).

Without any of those hints the tile falls back to `Fmt.smart`, which preserves whatever unit the OpenHAB state already carries and picks a sensible number of decimals.

### Sonos panel

Wraps a Sonos zone in a dedicated player tile that shows the current track, an optional album art image, transport controls (PREV / PLAY-PAUSE / NEXT), a volume slider, and an optional row of favourite preset buttons.

```json
{
  "type": "sonos",
  "title": "Sonos Kueche",
  "accentColor": "#f59e0b",
  "items": {
    "controller": "Sonos_Kitchen_Controller",
    "volume": "Sonos_Kitchen_Volume",
    "mute": "Sonos_Kitchen_Mute",
    "title": "Sonos_Kitchen_CurrentTitle",
    "artist": "Sonos_Kitchen_CurrentArtist",
    "album": "Sonos_Kitchen_CurrentAlbum",
    "albumArt": "Sonos_Kitchen_AlbumArt_Url",
    "state": "Sonos_Kitchen_State",
    "track": "Sonos_Kitchen_CurrentTrack",
    "favorite": "Sonos_Kitchen_Favotite"
  },
  "favorites": [
    { "label": "SWR3",     "command": "SWR3" },
    { "label": "Rockland", "command": "Rockland Radio" }
  ]
}
```

All `items.*` keys are optional - the panel hides unbound controls automatically:

- `controller` - Player item; PLAY / PAUSE / NEXT / PREVIOUS commands are sent on transport button presses.
- `volume` - Dimmer item (0..100). Renders as a slider.
- `mute` - Switch item. Adds a MUTE / UNMUTE button.
- `title`, `artist`, `album` - String items used to build the now-playing label.
- `track` - String item used as fallback when `title`/`artist` are absent.
- `albumArt` - String item with a URL pointing at the album art image. Hidden when empty or unreachable.
- `state` - String item used to pick the PLAY vs. PAUSE icon and surface the current state.
- `favorite` - String item that triggers favourite playback when any of the `favorites` buttons is pressed.

`favorites` is a list of `{ label, command, accentColor? }` entries. Pressing one publishes `command` to the `favorite` item.

### Grafana panel

Embeds a single Grafana panel as a self-refreshing PNG served by Grafana's `/render/d-solo/...` endpoint. No `QtWebEngine` / Chromium is pulled into HomeUI - rendering happens entirely on the Grafana server side and HomeUI just displays the resulting image, which makes this very light for a Pi kiosk.

```json
{
  "type": "grafana",
  "title": "Temperaturen",
  "baseUrl": "http://192.168.0.95:3000",
  "dashboardUid": "cdnrwiq71tc74c",
  "slug": "home",
  "panelId": 1,
  "orgId": 1,
  "theme": "dark",
  "from": "now-2d",
  "to": "now",
  "timezone": "Europe/Berlin",
  "refreshInterval": 60,
  "renderScale": 1,
  "extraParams": {
    "var-room": "Wohnzimmer"
  }
}
```

- `baseUrl` (required) - the Grafana root URL, e.g. `http://grafana.local:3000`. Trailing slashes are stripped.
- `dashboardUid` (required) - the UID portion of the dashboard URL (`/d/<uid>/<slug>`).
- `slug` - the dashboard slug portion. Cosmetic for Grafana, defaults to `"dashboard"`.
- `panelId` (required, > 0) - the panel id to render. Find it in Grafana via _Share - Link_ -> the `viewPanel=N` query parameter, or _Inspect - Panel JSON - id_.
- `orgId` (default `1`) - Grafana organisation id.
- `theme` - `"dark"` (default) or `"light"`.
- `from` / `to` - Grafana relative or absolute time range (`now-2d`, `now`, `now-7d/d`, etc.). Defaults to `now-2d` / `now`.
- `timezone` - optional IANA timezone forwarded as Grafana's `tz` query parameter.
- `refreshInterval` - seconds between PNG refreshes. Minimum effective interval is 5 s, default is 60 s.
- `renderScale` - upscale factor forwarded as Grafana's `scale` parameter for Hi-DPI panels. Set to `2` on a 4K monitor.
- `extraParams` - free-form object of additional query parameters (`var-room`, `kiosk`, custom variables, etc.). Values can be strings, numbers, or arrays (arrays repeat the key).

The panel automatically queries Grafana for the actual pixel dimensions of the tile (multiplied by `Screen.devicePixelRatio`), so the image always arrives at native resolution. Resizing the window debounces re-renders by 500 ms to avoid hammering Grafana.

**One-time Grafana setup:**

The `/render/d-solo/...` endpoint requires the **Grafana Image Renderer** to be available. There are two ways to deploy it; pick **one**.

#### Option A - Renderer as a Grafana plugin (x86_64 only)

Works for Grafana running on `linux-x64`, `darwin-amd64`, or `windows-amd64`. **Does not work on arm64** (Raspberry Pi, arm64 NAS) - the plugin's binaries are not built for those architectures and `grafana-cli plugins install grafana-image-renderer` will fail with `[plugin.archNotFound] grafana-image-renderer is not compatible with your system architecture: linux-arm64`.

```bash
grafana-cli plugins install grafana-image-renderer
sudo systemctl restart grafana-server
```

#### Option B - Renderer as a remote Docker service (works on arm64)

The official `grafana/grafana-image-renderer` Docker image is multi-arch and includes a working arm64 build. Grafana itself stays as-is and talks to the container over HTTP.

1. Run the renderer container on the same host as Grafana (or any reachable host on the LAN):

   ```bash
   docker run -d \
     --name grafana-renderer \
     --restart unless-stopped \
     --network host \
     grafana/grafana-image-renderer:latest
   ```

   The image listens on port `8081` by default. If you cannot use `--network host` (e.g. on Synology DSM), publish the port and adjust the URLs below: `-p 8081:8081`.

2. Tell Grafana to use it. In `/etc/grafana/grafana.ini` (or the container's mounted config):

   ```ini
   [rendering]
   server_url  = http://localhost:8081/render
   callback_url = http://192.168.0.95:3000/
   ```

   - `server_url` is what **Grafana** uses to reach the **renderer**. `localhost:8081` works whenever the renderer container runs on the same host as Grafana with `--network host`.
   - `callback_url` is what the **renderer's headless Chromium** uses to fetch your dashboard. **Always use the host's LAN IP / DNS name here, not `localhost`.** From inside the renderer container, `localhost` resolves to the container itself (or, with `--network host`, to the host's loopback interface where Grafana may not be listening if Grafana is also dockerized), so requests to `http://localhost:3000/` typically time out with `status=408` after ~35 s. The LAN IP works in all common topologies (Grafana on host, Grafana in Docker with `-p 3000:3000`, separate hosts).

   You can verify the renderer can reach Grafana before restarting anything:

   ```bash
   docker exec grafana-renderer curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://192.168.0.95:3000/login
   # expected: HTTP 200
   ```

3. Restart Grafana:

   ```bash
   sudo systemctl restart grafana-server
   ```

4. Verify by hitting a render URL directly in a browser - it should return a PNG, not HTML:

   ```text
   http://<grafana-host>:3000/render/d-solo/<dashboardUid>/<slug>?orgId=1&panelId=1&width=600&height=400
   ```

#### Anonymous access (kiosk only)

For an unauthenticated kiosk it's cleanest to allow anonymous Viewer access in `/etc/grafana/grafana.ini`:

```ini
[auth.anonymous]
enabled = true
org_name = Main Org.
org_role = Viewer
```

Restart Grafana again afterwards. If your Grafana instance does require authentication, see the **Auth note** below.

**Auth note:** `QtQuick.Image` cannot attach custom HTTP headers, so bearer-token / API-key authentication is not supported out of the box. If your Grafana mandates auth, the current options are anonymous access (above) or running Grafana behind a reverse proxy that injects the API key. Native API-key support would require a small `QQuickImageProvider` similar to `src/MjpegView.cpp` - file an issue if you need it.

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

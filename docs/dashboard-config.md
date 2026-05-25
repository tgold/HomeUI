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

If `command` is provided, the control always sends that command. Otherwise it toggles between `onCommand` and `offCommand`.

## Validation

The app validates the JSON at startup. If validation fails, the UI displays the validation error and offers a reload button.

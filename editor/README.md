# HomeUI Dashboard Editor

Standalone web editor for `config/dashboard.json`. Run it on your dev PC while editing layout; shut it down when you are done. The panel app is unchanged and continues to load the same JSON file.

## Features

- Rearrange panels on masonry, grid, and columns pages
- Edit panel title, type, height, column pin, and spans
- Add/remove panels with minimal valid stubs
- Drag overlay positions on `schematic` and `irrigationFloorplan` panels
- Placeholder layout preview sized like the 1280px panel viewport
- Save through the existing Python validator (`scripts/validate-dashboard.py`)

## Requirements

- Node.js 20+
- Python 3 (for validation)

## Setup

```sh
cd editor
npm install
```

## Development

Starts the API on port **5174** and the UI on port **5173**:

```sh
npm run dev
```

Open http://127.0.0.1:5173

Environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `HOMEUI_CONFIG` | `../config/dashboard.json` | Dashboard file to edit |
| `EDITOR_HOST` | `127.0.0.1` | API bind address |
| `EDITOR_PORT` | `5174` | API port |

## Production build

```sh
npm run build
npm start
```

Serves the built UI and API together on `EDITOR_PORT`.

## Workflow

1. Start the editor and change layout or overlay positions.
2. Click **Save** — the file is written only if validation passes.
3. Deploy `config/dashboard.json` to the panel (`/etc/homeui/dashboard.json`).
4. HomeUI reloads automatically via its file watcher or MQTT reload topic.

## Tests

```sh
npm test
```

Runs shared layout/coordinate unit tests.

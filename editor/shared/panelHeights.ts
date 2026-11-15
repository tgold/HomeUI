import type { DashboardPanel } from "./types.js";

const TILE_HEIGHT = 76;
const PANEL_HEADER = 44;

function isTemperatureValue(control: Record<string, unknown>): boolean {
  const kind = String(control.kind ?? control.widget ?? "switch").toLowerCase();
  const format = String(control.format ?? "").toLowerCase();
  return kind === "value" && format === "temperature";
}

// Mirrors ControlsPanel: the first temperature value is header text when the
// panel also has other controls. Temperature-only panels keep every tile.
function hoistedTemperatureCount(controls: Record<string, unknown>[]): number {
  let firstTemp = -1;
  let hasOther = false;
  for (let i = 0; i < controls.length; i += 1) {
    if (isTemperatureValue(controls[i])) {
      if (firstTemp < 0) {
        firstTemp = i;
      }
    } else {
      hasOther = true;
    }
  }
  return hasOther && firstTemp >= 0 ? 1 : 0;
}

function controlsHeight(panel: DashboardPanel): number {
  const controls = panel.controls ?? [];
  const tilesPerRow = panel.tilesPerRow && panel.tilesPerRow > 0 ? panel.tilesPerRow : 2;
  const tileCount = Math.max(0, controls.length - hoistedTemperatureCount(controls));
  const rows = Math.max(1, Math.ceil(tileCount / tilesPerRow));
  return PANEL_HEADER + rows * TILE_HEIGHT + 16;
}

export function estimatePanelHeight(panel: DashboardPanel): number {
  if (panel.fillHeight === true) {
    return 400;
  }
  if (typeof panel.height === "number" && panel.height > 0) {
    return panel.height;
  }

  switch (panel.type) {
    case "irrigationFloorplan":
      return 520;
    case "schematic":
      return 420;
    case "grafana":
      return 280;
    case "camera":
      return 300;
    case "controls":
      return controlsHeight(panel);
    case "energy":
      return 220;
    case "sonos":
      return 320;
    case "room":
      return 280;
    case "mode":
      return 160;
    case "mqtt":
      return 200;
    default:
      return 160;
  }
}

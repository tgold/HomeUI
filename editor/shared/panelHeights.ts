import type { DashboardPanel } from "./types.js";

const TILE_HEIGHT = 76;
const PANEL_HEADER = 44;

function controlsHeight(panel: DashboardPanel): number {
  const controls = panel.controls ?? [];
  const tilesPerRow = panel.tilesPerRow && panel.tilesPerRow > 0 ? panel.tilesPerRow : 2;
  const rows = Math.max(1, Math.ceil(controls.length / tilesPerRow));
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

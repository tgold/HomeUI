import type { PanelType } from "./types.js";

export function createPanelStub(type: PanelType, title: string): Record<string, unknown> {
  switch (type) {
    case "controls":
      return { type, title, controls: [] };
    case "room":
      return { type, title, items: [] };
    case "energy":
      return { type, title, items: {} };
    case "camera":
      return { type, title, format: "placeholder", url: "" };
    case "mode":
      return { type, title, modes: [] };
    case "mqtt":
      return { type, title, items: [{ label: "Example", topic: "home/example" }] };
    case "sonos":
      return { type, title, items: { transport: "", volume: "" } };
    case "grafana":
      return {
        type,
        title,
        baseUrl: "http://localhost:3000",
        dashboardUid: "example",
        panelId: 1,
      };
    case "irrigationFloorplan":
      return {
        type,
        title,
        imageSource: "irrigation-floorplan.png",
        zones: [
          {
            id: "z1",
            label: "Zone 1",
            x: 0.5,
            y: 0.5,
            activityItem: "example_zone_activity",
          },
        ],
        sensors: [],
      };
    case "schematic":
      return {
        type,
        title,
        imageSource: "heat-pump-schematic.png",
        labels: [{ label: "Example", x: 0.5, y: 0.5, value: "--" }],
        controls: [],
      };
    default:
      return { type, title };
  }
}

export function isOverlayPanelType(type: string): boolean {
  return type === "irrigationFloorplan" || type === "schematic";
}

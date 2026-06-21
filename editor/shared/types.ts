export type PageLayout = "columns" | "grid" | "masonry";

export type PanelType =
  | "room"
  | "energy"
  | "camera"
  | "mode"
  | "controls"
  | "mqtt"
  | "sonos"
  | "grafana"
  | "irrigationFloorplan"
  | "schematic";

export interface DashboardPanel {
  type: PanelType | string;
  title?: string;
  height?: number;
  fillHeight?: boolean;
  column?: number;
  columnSpan?: number;
  rowSpan?: number;
  tilesPerRow?: number;
  controls?: Record<string, unknown>[];
  labels?: Record<string, unknown>[];
  zones?: Record<string, unknown>[];
  sensors?: Record<string, unknown>[];
  imageSource?: string;
  [key: string]: unknown;
}

export interface DashboardColumn {
  width?: number;
  fillWidth?: boolean;
  panels: DashboardPanel[];
}

export interface DashboardPage {
  id?: string;
  title: string;
  layout?: PageLayout;
  columns?: number | DashboardColumn[];
  columnWidth?: number;
  panels?: DashboardPanel[];
}

export interface DashboardConfig {
  pages: DashboardPage[];
}

export interface PlacedPanel {
  index: number;
  panel: DashboardPanel;
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface ValidationResult {
  ok: boolean;
  errors: string[];
  pageCount?: number;
  panelCount?: number;
}

export const PANEL_TYPES: PanelType[] = [
  "room",
  "energy",
  "camera",
  "mode",
  "controls",
  "mqtt",
  "sonos",
  "grafana",
  "irrigationFloorplan",
  "schematic",
];

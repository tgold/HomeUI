import { PAGE_MARGIN, PAGE_SPACING } from "./constants.js";
import { estimatePanelHeight } from "./panelHeights.js";
import type { DashboardColumn, DashboardPanel, PlacedPanel } from "./types.js";

function panelHeight(panel: DashboardPanel): number {
  if (panel.fillHeight === true) {
    return 400;
  }
  if (typeof panel.height === "number" && panel.height > 0) {
    return panel.height;
  }
  return estimatePanelHeight(panel);
}

export function columnsLayout(
  columns: DashboardColumn[],
  hostWidth: number,
): PlacedPanel[] {
  const margins = PAGE_MARGIN;
  const spacing = PAGE_SPACING;
  const placed: PlacedPanel[] = [];

  const fixedWidths = columns.map((col) =>
    col.width && col.width > 0 ? col.width : 0,
  );
  const fillCount = columns.filter((col) => col.fillWidth === true).length;
  const fixedTotal =
    fixedWidths.reduce((sum, w) => sum + w, 0) +
    Math.max(0, columns.length - 1) * spacing;
  const remaining = Math.max(120, hostWidth - 2 * margins - fixedTotal);
  const fillWidth = fillCount > 0 ? Math.floor(remaining / fillCount) : 292;

  let x = margins;
  let globalIndex = 0;

  for (let colIndex = 0; colIndex < columns.length; colIndex++) {
    const column = columns[colIndex];
    const colWidth =
      fixedWidths[colIndex] > 0
        ? fixedWidths[colIndex]
        : column.fillWidth === true
          ? fillWidth
          : 292;

    let y = margins;
    for (let panelIndex = 0; panelIndex < column.panels.length; panelIndex++) {
      const panel = column.panels[panelIndex];
      const height = panelHeight(panel);
      placed.push({
        index: globalIndex,
        panel,
        x,
        y,
        width: colWidth,
        height,
      });
      y += height + spacing;
      globalIndex++;
    }

    x += colWidth + spacing;
  }

  return placed;
}

export function columnsContentHeight(placed: PlacedPanel[]): number {
  if (placed.length === 0) {
    return PAGE_MARGIN * 2;
  }
  return Math.max(...placed.map((p) => p.y + p.height)) + PAGE_MARGIN;
}

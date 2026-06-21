import { PAGE_MARGIN, PAGE_SPACING } from "./constants.js";
import { estimatePanelHeight } from "./panelHeights.js";
import type { DashboardPage, DashboardPanel, PlacedPanel } from "./types.js";

function panelHeight(panel: DashboardPanel): number {
  if (panel.fillHeight === true) {
    return 400;
  }
  if (typeof panel.height === "number" && panel.height > 0) {
    return panel.height;
  }
  return estimatePanelHeight(panel);
}

export function gridLayout(
  page: DashboardPage,
  panels: DashboardPanel[],
  hostWidth: number,
): PlacedPanel[] {
  const columnsCount = Math.max(1, Number(page.columns ?? 3));
  const margins = PAGE_MARGIN;
  const spacing = PAGE_SPACING;
  const innerWidth = hostWidth - 2 * margins - (columnsCount - 1) * spacing;
  const cellWidth = Math.max(120, Math.floor(innerWidth / columnsCount));

  const rowHeights: number[] = [];
  const placed: PlacedPanel[] = [];

  for (let i = 0; i < panels.length; i++) {
    const panel = panels[i];
    const colSpan = Math.min(Math.max(1, Number(panel.columnSpan ?? 1)), columnsCount);
    const rowSpan = Math.max(1, Number(panel.rowSpan ?? 1));

    const col = i % columnsCount;
    const row = Math.floor(i / columnsCount);

    while (rowHeights.length <= row + rowSpan - 1) {
      rowHeights.push(0);
    }

    const height = panelHeight(panel);
    for (let r = row; r < row + rowSpan; r++) {
      rowHeights[r] = Math.max(rowHeights[r], height);
    }

    const width = colSpan * cellWidth + (colSpan - 1) * spacing;
    let y = margins;
    for (let r = 0; r < row; r++) {
      y += rowHeights[r] + spacing;
    }

    placed.push({
      index: i,
      panel,
      x: margins + col * (cellWidth + spacing),
      y,
      width,
      height: rowHeights.slice(row, row + rowSpan).reduce((a, b) => a + b, 0) + spacing * (rowSpan - 1),
    });
  }

  return placed;
}

export function gridContentHeight(placed: PlacedPanel[]): number {
  if (placed.length === 0) {
    return PAGE_MARGIN * 2;
  }
  return Math.max(...placed.map((p) => p.y + p.height)) + PAGE_MARGIN;
}

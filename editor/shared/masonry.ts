import {
  DEFAULT_COLUMN_WIDTH,
  PAGE_MARGIN,
  PAGE_SPACING,
} from "./constants.js";
import { estimatePanelHeight } from "./panelHeights.js";
import type { DashboardPage, DashboardPanel, PlacedPanel } from "./types.js";

function layoutValue<T>(page: DashboardPage, key: keyof DashboardPage, fallback: T): T {
  const value = page[key];
  if (value === undefined || value === null) {
    return fallback;
  }
  return value as T;
}

function panelHeight(panel: DashboardPanel): number {
  if (panel.fillHeight === true) {
    return -1;
  }
  if (typeof panel.height === "number" && panel.height > 0) {
    return panel.height;
  }
  return estimatePanelHeight(panel);
}

export function masonryLayout(
  page: DashboardPage,
  panels: DashboardPanel[],
  hostWidth: number,
): PlacedPanel[] {
  if (panels.length === 0 || hostWidth <= 0) {
    return [];
  }

  const margins = PAGE_MARGIN;
  const hspacing = PAGE_SPACING;
  const vspacing = PAGE_SPACING;
  const minColumnWidth = layoutValue(page, "columnWidth", DEFAULT_COLUMN_WIDTH);

  let columnsCount = Number(layoutValue(page, "columns", 0));
  if (!columnsCount || columnsCount <= 0) {
    const available = hostWidth - 2 * margins;
    if (available <= 0) {
      columnsCount = 3;
    } else {
      columnsCount = Math.max(
        1,
        Math.floor((available + hspacing) / (minColumnWidth + hspacing)),
      );
    }
  }

  const availableWidth = hostWidth - 2 * margins - (columnsCount - 1) * hspacing;
  const columnWidth = Math.max(120, Math.floor(availableWidth / Math.max(1, columnsCount)));
  const fullWidth = hostWidth - 2 * margins;

  const heights = new Array<number>(columnsCount).fill(margins);
  const placed: PlacedPanel[] = [];

  for (let i = 0; i < panels.length; i++) {
    const panel = panels[i];
    let span = Number(panel.columnSpan ?? 1);
    if (!Number.isFinite(span) || span < 1) {
      span = 1;
    }
    const effSpan = Math.min(Math.floor(span), columnsCount);

    let startCol = 0;
    let placeY = 0;

    if (effSpan >= columnsCount) {
      placeY = Math.max(...heights);
      startCol = 0;
    } else if (effSpan > 1) {
      let bestY = Number.POSITIVE_INFINITY;
      for (let s = 0; s <= columnsCount - effSpan; s++) {
        let topY = 0;
        for (let k = s; k < s + effSpan; k++) {
          topY = Math.max(topY, heights[k]);
        }
        if (topY < bestY) {
          bestY = topY;
          startCol = s;
        }
      }
      placeY = bestY;
    } else {
      const preferredRaw = Number(panel.column ?? 0);
      const preferred = Math.floor(preferredRaw) - 1;
      if (Number.isFinite(preferred) && preferred >= 0 && preferred < columnsCount) {
        startCol = preferred;
        placeY = heights[preferred];
      } else {
        let shortest = 0;
        for (let k = 1; k < columnsCount; k++) {
          if (heights[k] < heights[shortest]) {
            shortest = k;
          }
        }
        startCol = shortest;
        placeY = heights[shortest];
      }
    }

    const panelWidth =
      effSpan >= columnsCount
        ? fullWidth
        : effSpan * columnWidth + (effSpan - 1) * hspacing;

    const explicitHeight = panelHeight(panel);
    const resolvedHeight = explicitHeight > 0 ? explicitHeight : estimatePanelHeight(panel);

    placed.push({
      index: i,
      panel,
      x: margins + startCol * (columnWidth + hspacing),
      y: placeY,
      width: panelWidth,
      height: resolvedHeight,
    });

    const consumedBottom = placeY + resolvedHeight + vspacing;
    if (effSpan >= columnsCount) {
      for (let c = 0; c < columnsCount; c++) {
        heights[c] = consumedBottom;
      }
    } else {
      for (let c = startCol; c < startCol + effSpan; c++) {
        heights[c] = consumedBottom;
      }
    }
  }

  return placed;
}

export function masonryContentHeight(placed: PlacedPanel[]): number {
  if (placed.length === 0) {
    return PAGE_MARGIN * 2;
  }
  return Math.max(...placed.map((p) => p.y + p.height)) + PAGE_MARGIN;
}

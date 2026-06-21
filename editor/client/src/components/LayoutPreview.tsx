import { PREVIEW_HOST_WIDTH } from "@shared/constants";
import { columnsLayout, columnsContentHeight } from "@shared/columnsLayout";
import { gridContentHeight, gridLayout } from "@shared/gridLayout";
import { masonryContentHeight, masonryLayout } from "@shared/masonry";
import type { DashboardColumn, DashboardPage, DashboardPanel, PlacedPanel } from "@shared/types";
import { getPageColumns, isColumnsLayout, pageLayout } from "../pageUtils";

interface LayoutPreviewProps {
  page: DashboardPage;
  panels: DashboardPanel[];
  columns?: DashboardColumn[];
  selectedIndex: number | null;
  onSelect: (index: number) => void;
}

function computePlaced(
  page: DashboardPage,
  panels: DashboardPanel[],
  columns: DashboardColumn[],
): { placed: PlacedPanel[]; height: number } {
  const layout = pageLayout(page);
  if (layout === "columns") {
    const placed = columnsLayout(columns, PREVIEW_HOST_WIDTH);
    return { placed, height: columnsContentHeight(placed) };
  }
  if (layout === "grid") {
    const placed = gridLayout(page, panels, PREVIEW_HOST_WIDTH);
    return { placed, height: gridContentHeight(placed) };
  }
  const placed = masonryLayout(page, panels, PREVIEW_HOST_WIDTH);
  return { placed, height: masonryContentHeight(placed) };
}

export function LayoutPreview({
  page,
  panels,
  columns,
  selectedIndex,
  onSelect,
}: LayoutPreviewProps) {
  const columnDefs = columns ?? (isColumnsLayout(page) ? getPageColumns(page) : []);
  const { placed, height } = computePlaced(page, panels, columnDefs);

  return (
    <div className="preview-frame">
      <div
        className="preview-canvas"
        style={{ width: PREVIEW_HOST_WIDTH, height: Math.max(height, 320) }}
      >
        {placed.map((entry) => (
          <button
            key={`preview-${entry.index}`}
            type="button"
            className={`preview-panel ${selectedIndex === entry.index ? "selected" : ""}`}
            style={{
              left: entry.x,
              top: entry.y,
              width: entry.width,
              height: entry.height,
            }}
            onClick={() => onSelect(entry.index)}
          >
            <div className="type">{entry.panel.type}</div>
            <div className="title">{entry.panel.title ?? "Untitled"}</div>
          </button>
        ))}
      </div>
    </div>
  );
}

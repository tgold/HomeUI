import { describe, expect, it } from "vitest";
import { masonryLayout, masonryContentHeight } from "./masonry.js";
import {
  computePaintedRect,
  normFromOverlayX,
  normFromOverlayY,
  overlayX,
  overlayY,
} from "./overlayCoords.js";
import type { DashboardPage } from "./types.js";

describe("masonryLayout", () => {
  it("places pinned column panels in the preferred column", () => {
    const page: DashboardPage = {
      title: "Test",
      layout: "masonry",
      columns: 3,
      panels: [
        { type: "controls", title: "A", height: 100 },
        { type: "controls", title: "B", height: 100, column: 3 },
        { type: "controls", title: "C", height: 100 },
      ],
    };

    const placed = masonryLayout(page, page.panels!, 1280);
    expect(placed[1].x).toBeGreaterThan(placed[0].x);
    expect(placed[1].y).toBe(12);
  });

  it("computes content height from placed panels", () => {
    const page: DashboardPage = {
      title: "Test",
      layout: "masonry",
      columns: 2,
      panels: [{ type: "grafana", title: "G", height: 200 }],
    };
    const placed = masonryLayout(page, page.panels!, 800);
    expect(masonryContentHeight(placed)).toBe(12 + 200 + 12);
  });
});

describe("overlayCoords", () => {
  it("letterboxes a wide image inside a square host", () => {
    const host = { x: 0, y: 0, width: 400, height: 400 };
    const painted = computePaintedRect(host, 800, 400);
    expect(painted.width).toBe(400);
    expect(painted.height).toBe(200);
    expect(painted.y).toBe(100);
  });

  it("round-trips normalized coordinates", () => {
    const host = { x: 0, y: 0, width: 400, height: 400 };
    const painted = computePaintedRect(host, 800, 400);
    const normX = 0.52;
    const normY = 0.12;
    const px = overlayX(normX, painted, host);
    const py = overlayY(normY, painted, host);
    expect(normFromOverlayX(px, painted, host)).toBeCloseTo(normX, 5);
    expect(normFromOverlayY(py, painted, host)).toBeCloseTo(normY, 5);
  });
});

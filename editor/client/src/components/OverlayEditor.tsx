import { useEffect, useMemo, useRef, useState } from "react";
import {
  centerPosition,
  computePaintedRect,
  labelPosition,
  normFromCenterDrag,
  normFromLabelDrag,
} from "@shared/overlayCoords";
import type { DashboardPanel } from "@shared/types";
import { assetUrl } from "../api";

type OverlayKind = "zone" | "sensor" | "label" | "control";

interface OverlaySelection {
  kind: OverlayKind;
  index: number;
}

interface OverlayEditorProps {
  panel: DashboardPanel;
  onChange: (panel: DashboardPanel) => void;
  onClose: () => void;
}

interface OverlayItem {
  kind: OverlayKind;
  index: number;
  label: string;
  x: number;
  y: number;
  anchor?: string;
  anchorY?: string;
  width: number;
  height: number;
  zone?: boolean;
}

function gutterSide(control: Record<string, unknown>): string {
  return String(control.gutter ?? "").toLowerCase();
}

function overlayItems(panel: DashboardPanel): OverlayItem[] {
  const items: OverlayItem[] = [];

  if (panel.type === "irrigationFloorplan") {
    (panel.zones ?? []).forEach((zone, index) => {
      items.push({
        kind: "zone",
        index,
        label: String(zone.label ?? `Zone ${index + 1}`),
        x: Number(zone.x ?? 0.5),
        y: Number(zone.y ?? 0.5),
        width: 18,
        height: 18,
        zone: true,
      });
    });
    (panel.sensors ?? []).forEach((sensor, index) => {
      items.push({
        kind: "sensor",
        index,
        label: String(sensor.label ?? `Sensor ${index + 1}`),
        x: Number(sensor.x ?? 0.1),
        y: Number(sensor.y ?? 0.1),
        width: 110,
        height: 28,
      });
    });
  }

  if (panel.type === "schematic") {
    (panel.labels ?? []).forEach((label, index) => {
      items.push({
        kind: "label",
        index,
        label: String(label.label ?? `Label ${index + 1}`),
        x: Number(label.x ?? 0.5),
        y: Number(label.y ?? 0.5),
        anchor: String(label.anchor ?? "center"),
        anchorY: String(label.anchorY ?? "center"),
        width: Number(label.width ?? 110),
        height: Number(label.height ?? 28),
      });
    });
    (panel.controls ?? []).forEach((control, index) => {
      const side = gutterSide(control);
      if (side === "left" || side === "right") {
        return;
      }
      items.push({
        kind: "control",
        index,
        label: String(control.label ?? `Control ${index + 1}`),
        x: Number(control.x ?? 0.5),
        y: Number(control.y ?? 0.5),
        width: Number(control.width ?? 168),
        height: Number(control.height ?? 84),
      });
    });
  }

  return items;
}

export function OverlayEditor({ panel, onChange, onClose }: OverlayEditorProps) {
  const stageRef = useRef<HTMLDivElement>(null);
  const [selection, setSelection] = useState<OverlaySelection | null>(null);
  const [dragging, setDragging] = useState<OverlaySelection | null>(null);
  const [imageSize, setImageSize] = useState({ width: 1, height: 1 });
  const [stageSize, setStageSize] = useState({ width: 960, height: 540 });

  const imageSource = String(panel.imageSource ?? "");
  const items = useMemo(() => overlayItems(panel), [panel]);

  useEffect(() => {
    const stage = stageRef.current;
    if (!stage) {
      return;
    }
    const observer = new ResizeObserver((entries) => {
      const entry = entries[0];
      if (entry) {
        setStageSize({
          width: entry.contentRect.width,
          height: entry.contentRect.height,
        });
      }
    });
    observer.observe(stage);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!imageSource) {
      return;
    }
    const img = new Image();
    img.onload = () => setImageSize({ width: img.naturalWidth, height: img.naturalHeight });
    img.src = assetUrl(imageSource);
  }, [imageSource]);

  const host = { x: 0, y: 0, width: stageSize.width, height: stageSize.height };
  const painted = computePaintedRect(host, imageSize.width, imageSize.height);

  const updateItemPosition = (item: OverlayItem, x: number, y: number) => {
    const next = structuredClone(panel) as DashboardPanel;
    if (item.kind === "zone") {
      const zones = [...(next.zones ?? [])];
      zones[item.index] = { ...zones[item.index], x, y };
      next.zones = zones;
    } else if (item.kind === "sensor") {
      const sensors = [...(next.sensors ?? [])];
      sensors[item.index] = { ...sensors[item.index], x, y };
      next.sensors = sensors;
    } else if (item.kind === "label") {
      const labels = [...(next.labels ?? [])];
      labels[item.index] = { ...labels[item.index], x, y };
      next.labels = labels;
    } else {
      const controls = [...(next.controls ?? [])];
      controls[item.index] = { ...controls[item.index], x, y };
      next.controls = controls;
    }
    onChange(next);
  };

  const addOverlayItem = () => {
    const next = structuredClone(panel) as DashboardPanel;
    if (panel.type === "irrigationFloorplan") {
      const zones = [...(next.zones ?? [])];
      zones.push({
        id: `z${zones.length + 1}`,
        label: `Zone ${zones.length + 1}`,
        x: 0.5,
        y: 0.5,
        activityItem: "example_zone_activity",
      });
      next.zones = zones;
    } else {
      const labels = [...(next.labels ?? [])];
      labels.push({ label: `Label ${labels.length + 1}`, x: 0.5, y: 0.5, value: "--" });
      next.labels = labels;
    }
    onChange(next);
  };

  const removeOverlayItem = (item: OverlayItem) => {
    const next = structuredClone(panel) as DashboardPanel;
    if (item.kind === "zone") {
      next.zones = (next.zones ?? []).filter((_, index) => index !== item.index);
    } else if (item.kind === "sensor") {
      next.sensors = (next.sensors ?? []).filter((_, index) => index !== item.index);
    } else if (item.kind === "label") {
      next.labels = (next.labels ?? []).filter((_, index) => index !== item.index);
    } else {
      next.controls = (next.controls ?? []).filter((_, index) => index !== item.index);
    }
    onChange(next);
    setSelection(null);
  };

  const handlePointerDown = (
    event: React.PointerEvent<HTMLDivElement>,
    item: OverlayItem,
  ) => {
    event.preventDefault();
    setSelection({ kind: item.kind, index: item.index });
    setDragging({ kind: item.kind, index: item.index });
    event.currentTarget.setPointerCapture(event.pointerId);
  };

  const handlePointerMove = (
    event: React.PointerEvent<HTMLDivElement>,
    item: OverlayItem,
  ) => {
    if (
      !dragging ||
      dragging.kind !== item.kind ||
      dragging.index !== item.index ||
      !stageRef.current
    ) {
      return;
    }

    const rect = stageRef.current.getBoundingClientRect();
    const localX = event.clientX - rect.left;
    const localY = event.clientY - rect.top;

    let nextCoords: { x: number; y: number };
    if (item.kind === "label") {
      nextCoords = normFromLabelDrag(
        localX,
        localY,
        host,
        painted,
        item.width,
        item.height,
        item.anchor,
        item.anchorY,
      );
    } else {
      nextCoords = normFromCenterDrag(localX, localY, host, painted);
    }
    updateItemPosition(item, nextCoords.x, nextCoords.y);
  };

  const handlePointerUp = (event: React.PointerEvent<HTMLDivElement>) => {
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
    setDragging(null);
  };

  return (
    <div className="overlay-editor">
      <div className="panel-actions">
        <button type="button" className="btn" onClick={onClose}>
          Back to layout
        </button>
        <button type="button" className="btn primary" onClick={addOverlayItem}>
          Add overlay item
        </button>
      </div>

      <div
        ref={stageRef}
        className="overlay-stage"
        style={{ width: "min(100%, 960px)", height: 540 }}
      >
        {imageSource ? <img src={assetUrl(imageSource)} alt={panel.title ?? "Overlay"} /> : null}
        {items.map((item) => {
          const selected =
            selection?.kind === item.kind && selection.index === item.index;
          const pos =
            item.kind === "label"
              ? labelPosition(
                  item.x,
                  item.y,
                  item.width,
                  item.height,
                  item.anchor,
                  item.anchorY,
                  painted,
                  host,
                )
              : centerPosition(item.x, item.y, item.width, item.height, painted, host);

          return (
            <div
              key={`${item.kind}-${item.index}`}
              className={`overlay-marker ${item.zone ? "zone" : ""} ${selected ? "selected" : ""}`}
              style={{
                left: pos.x,
                top: pos.y,
                width: item.zone ? 18 : item.width,
                height: item.zone ? 18 : item.height,
              }}
              onPointerDown={(event) => handlePointerDown(event, item)}
              onPointerMove={(event) => handlePointerMove(event, item)}
              onPointerUp={handlePointerUp}
            >
              {!item.zone ? item.label : null}
            </div>
          );
        })}
      </div>

      <div className="overlay-list">
        {items.map((item) => (
          <div key={`list-${item.kind}-${item.index}`} className="panel-row">
            <div className="meta">
              <strong>{item.label}</strong>
              <span>
                {item.kind} · x={item.x.toFixed(3)}, y={item.y.toFixed(3)}
              </span>
            </div>
            <button type="button" className="btn" onClick={() => setSelection(item)}>
              Select
            </button>
            <button type="button" className="btn danger" onClick={() => removeOverlayItem(item)}>
              Remove
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

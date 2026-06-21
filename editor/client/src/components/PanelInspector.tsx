import type { DashboardPanel, PanelType } from "@shared/types";
import { PANEL_TYPES } from "@shared/types";
import { isOverlayPanelType } from "@shared/panelStubs";

interface PanelInspectorProps {
  panel: DashboardPanel | null;
  layout: string;
  onChange: (panel: DashboardPanel) => void;
  onRemove: () => void;
  onOpenOverlay: () => void;
}

function numberField(
  label: string,
  value: number | undefined,
  onChange: (value: number | undefined) => void,
) {
  return (
    <label key={label}>
      {label}
      <input
        type="number"
        value={value ?? ""}
        onChange={(event) => {
          const next = event.target.value;
          onChange(next === "" ? undefined : Number(next));
        }}
      />
    </label>
  );
}

export function PanelInspector({
  panel,
  layout,
  onChange,
  onRemove,
  onOpenOverlay,
}: PanelInspectorProps) {
  if (!panel) {
    return (
      <aside className="inspector">
        <h2 className="section-title">Inspector</h2>
        <p className="empty-state">Select a panel to edit its layout properties.</p>
      </aside>
    );
  }

  const update = (patch: Partial<DashboardPanel>) => onChange({ ...panel, ...patch });

  return (
    <aside className="inspector">
      <h2 className="section-title">Inspector</h2>
      <div className="inspector-form">
        <label>
          Title
          <input
            value={panel.title ?? ""}
            onChange={(event) => update({ title: event.target.value })}
          />
        </label>
        <label>
          Type
          <select
            value={panel.type}
            onChange={(event) => update({ type: event.target.value as PanelType })}
          >
            {PANEL_TYPES.map((type) => (
              <option key={type} value={type}>
                {type}
              </option>
            ))}
          </select>
        </label>
        {numberField("Height", panel.height, (height) => update({ height }))}
        {(layout === "masonry" || layout === "grid") &&
          numberField("Column span", panel.columnSpan, (columnSpan) => update({ columnSpan }))}
        {layout === "masonry" &&
          numberField("Column (1-based pin)", panel.column, (column) => update({ column }))}
        {layout === "grid" && numberField("Row span", panel.rowSpan, (rowSpan) => update({ rowSpan }))}
        <label>
          Fill height
          <select
            value={panel.fillHeight ? "true" : "false"}
            onChange={(event) => update({ fillHeight: event.target.value === "true" })}
          >
            <option value="false">No</option>
            <option value="true">Yes</option>
          </select>
        </label>
      </div>
      <div className="inspector-actions">
        {isOverlayPanelType(String(panel.type)) && (
          <button type="button" className="btn primary" onClick={onOpenOverlay}>
            Edit overlay positions
          </button>
        )}
        <button type="button" className="btn danger" onClick={onRemove}>
          Remove panel
        </button>
      </div>
    </aside>
  );
}

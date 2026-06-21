import { useCallback, useEffect, useMemo, useState } from "react";
import type { DashboardColumn, DashboardConfig, DashboardPage, DashboardPanel } from "@shared/types";
import { createPanelStub } from "@shared/panelStubs";
import type { PanelType } from "@shared/types";
import { assetUrl, fetchConfig, fetchMeta, saveConfig, validateConfig } from "./api";
import { ColumnsEditor } from "./components/ColumnsEditor";
import { LayoutPreview } from "./components/LayoutPreview";
import { OverlayEditor } from "./components/OverlayEditor";
import { PageSidebar } from "./components/PageSidebar";
import { PanelInspector } from "./components/PanelInspector";
import { PanelListEditor } from "./components/PanelListEditor";
import {
  getPageColumns,
  getPagePanels,
  isColumnsLayout,
  pageLayout,
  setPageColumns,
  setPagePanels,
  updatePageAt,
} from "./pageUtils";

type ViewMode = "layout" | "overlay";

function findPanelLocation(page: DashboardPage, globalIndex: number): {
  colIndex: number;
  panelIndex: number;
} | null {
  if (!isColumnsLayout(page)) {
    return globalIndex >= 0 ? { colIndex: -1, panelIndex: globalIndex } : null;
  }
  let cursor = 0;
  const columns = getPageColumns(page);
  for (let colIndex = 0; colIndex < columns.length; colIndex++) {
    for (let panelIndex = 0; panelIndex < columns[colIndex].panels.length; panelIndex++) {
      if (cursor === globalIndex) {
        return { colIndex, panelIndex };
      }
      cursor++;
    }
  }
  return null;
}

function getSelectedPanel(page: DashboardPage, globalIndex: number | null): DashboardPanel | null {
  if (globalIndex === null || globalIndex < 0) {
    return null;
  }
  const location = findPanelLocation(page, globalIndex);
  if (!location) {
    return null;
  }
  if (isColumnsLayout(page)) {
    return getPageColumns(page)[location.colIndex]?.panels[location.panelIndex] ?? null;
  }
  return page.panels?.[location.panelIndex] ?? null;
}

function updateSelectedPanel(
  page: DashboardPage,
  globalIndex: number,
  panel: DashboardPanel,
): DashboardPage {
  const location = findPanelLocation(page, globalIndex);
  if (!location) {
    return page;
  }
  if (isColumnsLayout(page)) {
    const columns = getPageColumns(page).map((column) => ({
      ...column,
      panels: [...column.panels],
    }));
    columns[location.colIndex].panels[location.panelIndex] = panel;
    return setPageColumns(page, columns);
  }
  const panels = [...(page.panels ?? [])];
  panels[location.panelIndex] = panel;
  return setPagePanels(page, panels);
}

function removeSelectedPanel(page: DashboardPage, globalIndex: number): DashboardPage {
  const location = findPanelLocation(page, globalIndex);
  if (!location) {
    return page;
  }
  if (isColumnsLayout(page)) {
    const columns = getPageColumns(page).map((column) => ({
      ...column,
      panels: [...column.panels],
    }));
    columns[location.colIndex].panels.splice(location.panelIndex, 1);
    return setPageColumns(page, columns);
  }
  const panels = [...(page.panels ?? [])];
  panels.splice(location.panelIndex, 1);
  return setPagePanels(page, panels);
}

export default function App() {
  const [config, setConfig] = useState<DashboardConfig | null>(null);
  const [savedSnapshot, setSavedSnapshot] = useState<string>("");
  const [pageIndex, setPageIndex] = useState(0);
  const [selectedPanelIndex, setSelectedPanelIndex] = useState<number | null>(null);
  const [viewMode, setViewMode] = useState<ViewMode>("layout");
  const [configPath, setConfigPath] = useState("");
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errors, setErrors] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);

  const loadConfig = useCallback(async () => {
    setLoading(true);
    try {
      const [nextConfig, meta] = await Promise.all([fetchConfig(), fetchMeta()]);
      setConfig(nextConfig);
      setSavedSnapshot(JSON.stringify(nextConfig));
      setConfigPath(meta.configPath);
      setErrors([]);
      setStatusMessage(null);
      setPageIndex(0);
      setSelectedPanelIndex(null);
      setViewMode("layout");
    } catch (error) {
      setErrors([error instanceof Error ? error.message : "Failed to load config"]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadConfig();
  }, [loadConfig]);

  const dirty = useMemo(() => {
    if (!config) {
      return false;
    }
    return JSON.stringify(config) !== savedSnapshot;
  }, [config, savedSnapshot]);

  const currentPage = config?.pages[pageIndex] ?? null;

  const panels = currentPage ? getPagePanels(currentPage) : [];
  const columns = currentPage && isColumnsLayout(currentPage) ? getPageColumns(currentPage) : [];
  const selectedPanel =
    currentPage && selectedPanelIndex !== null
      ? getSelectedPanel(currentPage, selectedPanelIndex)
      : null;

  const updateCurrentPage = (page: DashboardPage) => {
    if (!config) {
      return;
    }
    setConfig(updatePageAt(config, pageIndex, page));
  };

  const handleSave = async () => {
    if (!config) {
      return;
    }
    setBusy(true);
    setStatusMessage(null);
    setErrors([]);
    try {
      const result = await saveConfig(config);
      if (!result.ok) {
        setErrors(result.errors);
        return;
      }
      setSavedSnapshot(JSON.stringify(config));
      setStatusMessage(
        `Saved ${result.pageCount ?? config.pages.length} pages, ${result.panelCount ?? panels.length} panels.`,
      );
    } catch (error) {
      setErrors([error instanceof Error ? error.message : "Save failed"]);
    } finally {
      setBusy(false);
    }
  };

  const handleValidate = async () => {
    if (!config) {
      return;
    }
    setBusy(true);
    setErrors([]);
    setStatusMessage(null);
    try {
      const result = await validateConfig(config);
      if (!result.ok) {
        setErrors(result.errors);
        return;
      }
      setStatusMessage("Draft validates successfully.");
    } catch (error) {
      setErrors([error instanceof Error ? error.message : "Validation failed"]);
    } finally {
      setBusy(false);
    }
  };

  const handleReload = async () => {
    if (dirty && !window.confirm("Discard unsaved changes and reload from disk?")) {
      return;
    }
    await loadConfig();
  };

  const handleAddPanel = () => {
    if (!currentPage) {
      return;
    }
    const type = (window.prompt("Panel type (e.g. controls, schematic):", "controls") ??
      "controls") as PanelType;
    const title = window.prompt("Panel title:", "New panel") ?? "New panel";
    const panel = createPanelStub(type, title) as DashboardPanel;

    if (isColumnsLayout(currentPage)) {
      const nextColumns = getPageColumns(currentPage).map((column, index) =>
        index === 0 ? { ...column, panels: [...column.panels, panel] } : column,
      );
      updateCurrentPage(setPageColumns(currentPage, nextColumns));
      setSelectedPanelIndex(getPagePanels({ ...currentPage, columns: nextColumns }).length - 1);
      return;
    }

    const nextPanels = [...(currentPage.panels ?? []), panel];
    updateCurrentPage(setPagePanels(currentPage, nextPanels));
    setSelectedPanelIndex(nextPanels.length - 1);
  };

  if (loading || !config || !currentPage) {
    return <div className="empty-state">Loading dashboard editor…</div>;
  }

  return (
    <div className="app-shell">
      <PageSidebar
        pages={config.pages}
        selectedIndex={pageIndex}
        onSelect={(index) => {
          setPageIndex(index);
          setSelectedPanelIndex(null);
          setViewMode("layout");
        }}
      />

      <main className="main-pane">
        <div className="toolbar">
          <strong>HomeUI Dashboard Editor</strong>
          <span className="spacer" />
          {dirty ? <span className="dirty">Unsaved changes</span> : null}
          <button type="button" className="btn" onClick={() => void handleReload()} disabled={busy}>
            Reload
          </button>
          <button type="button" className="btn" onClick={() => void handleValidate()} disabled={busy}>
            Validate
          </button>
          <button
            type="button"
            className="btn primary"
            onClick={() => void handleSave()}
            disabled={busy || !dirty}
          >
            Save
          </button>
        </div>

        <div className="view-tabs">
          <button
            type="button"
            className={`view-tab ${viewMode === "layout" ? "active" : ""}`}
            onClick={() => setViewMode("layout")}
          >
            Layout
          </button>
          {selectedPanel &&
          (selectedPanel.type === "schematic" || selectedPanel.type === "irrigationFloorplan") ? (
            <button
              type="button"
              className={`view-tab ${viewMode === "overlay" ? "active" : ""}`}
              onClick={() => setViewMode("overlay")}
            >
              Overlay editor
            </button>
          ) : null}
        </div>

        {viewMode === "overlay" && selectedPanel && selectedPanelIndex !== null ? (
          <OverlayEditor
            panel={selectedPanel}
            onChange={(panel) => {
              updateCurrentPage(updateSelectedPanel(currentPage, selectedPanelIndex, panel));
            }}
            onClose={() => setViewMode("layout")}
          />
        ) : (
          <>
            <div className="panel-actions" style={{ padding: "12px 16px 0" }}>
              <button type="button" className="btn primary" onClick={handleAddPanel}>
                Add panel
              </button>
            </div>

            {isColumnsLayout(currentPage) ? (
              <ColumnsEditor
                columns={columns}
                selectedIndex={selectedPanelIndex}
                onSelect={setSelectedPanelIndex}
                onChange={(nextColumns: DashboardColumn[]) =>
                  updateCurrentPage(setPageColumns(currentPage, nextColumns))
                }
              />
            ) : (
              <div style={{ padding: "0 16px" }}>
                <PanelListEditor
                  panels={panels}
                  selectedIndex={selectedPanelIndex}
                  onSelect={setSelectedPanelIndex}
                  onReorder={(nextPanels) =>
                    updateCurrentPage(setPagePanels(currentPage, nextPanels))
                  }
                />
              </div>
            )}

            <LayoutPreview
              page={currentPage}
              panels={panels}
              columns={columns}
              selectedIndex={selectedPanelIndex}
              onSelect={setSelectedPanelIndex}
            />
          </>
        )}

        <div style={{ padding: "0 16px 16px" }}>
          <small style={{ color: "#9aa7b8" }}>Editing {configPath}</small>
          {statusMessage ? <div className="success-box">{statusMessage}</div> : null}
          {errors.length > 0 ? (
            <div className="error-box">
              <strong>Validation errors</strong>
              <ul className="error-list">
                {errors.map((error) => (
                  <li key={error}>{error}</li>
                ))}
              </ul>
            </div>
          ) : null}
        </div>
      </main>

      <PanelInspector
        panel={selectedPanel}
        layout={pageLayout(currentPage)}
        onChange={(panel) => {
          if (selectedPanelIndex === null) {
            return;
          }
          updateCurrentPage(updateSelectedPanel(currentPage, selectedPanelIndex, panel));
        }}
        onRemove={() => {
          if (selectedPanelIndex === null) {
            return;
          }
          if (!window.confirm("Remove this panel?")) {
            return;
          }
          updateCurrentPage(removeSelectedPanel(currentPage, selectedPanelIndex));
          setSelectedPanelIndex(null);
          setViewMode("layout");
        }}
        onOpenOverlay={() => setViewMode("overlay")}
      />
    </div>
  );
}

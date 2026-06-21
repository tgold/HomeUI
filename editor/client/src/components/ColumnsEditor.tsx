import {
  DndContext,
  DragOverlay,
  PointerSensor,
  useDraggable,
  useDroppable,
  useSensor,
  useSensors,
  type DragEndEvent,
  type DragStartEvent,
} from "@dnd-kit/core";
import { useMemo, useState, type ReactNode } from "react";
import type { DashboardColumn, DashboardPanel } from "@shared/types";

interface ColumnsEditorProps {
  columns: DashboardColumn[];
  selectedIndex: number | null;
  onSelect: (globalIndex: number) => void;
  onChange: (columns: DashboardColumn[]) => void;
}

function panelId(colIndex: number, panelIndex: number): string {
  return `col-${colIndex}-panel-${panelIndex}`;
}

function DraggablePanel({
  panel,
  id,
  selected,
  onSelect,
}: {
  panel: DashboardPanel;
  id: string;
  selected: boolean;
  onSelect: () => void;
}) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({ id });
  const style = transform
    ? { transform: `translate3d(${transform.x}px, ${transform.y}px, 0)` }
    : undefined;

  return (
    <div
      ref={setNodeRef}
      className={`panel-row ${selected ? "selected" : ""} ${isDragging ? "dragging" : ""}`}
      style={style}
      onClick={onSelect}
    >
      <span className="drag-handle" {...attributes} {...listeners}>
        ::
      </span>
      <div className="meta">
        <strong>{panel.title ?? "Untitled"}</strong>
        <span>{panel.type}</span>
      </div>
    </div>
  );
}

function ColumnDropZone({
  columnIndex,
  title,
  children,
}: {
  columnIndex: number;
  title: string;
  children: ReactNode;
}) {
  const { setNodeRef, isOver } = useDroppable({ id: `column-${columnIndex}` });
  return (
    <div
      ref={setNodeRef}
      className="column-stack"
      style={isOver ? { borderColor: "#4c8bf5" } : undefined}
    >
      <h3>{title}</h3>
      {children}
    </div>
  );
}

export function ColumnsEditor({
  columns,
  selectedIndex,
  onSelect,
  onChange,
}: ColumnsEditorProps) {
  const [activeId, setActiveId] = useState<string | null>(null);
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }));

  const globalIndexMap = useMemo(() => {
    const map = new Map<string, number>();
    let global = 0;
    columns.forEach((column, colIndex) => {
      column.panels.forEach((_panel, panelIndex) => {
        map.set(panelId(colIndex, panelIndex), global);
        global++;
      });
    });
    return map;
  }, [columns]);

  const activePanel = useMemo(() => {
    if (!activeId) {
      return null;
    }
    for (let colIndex = 0; colIndex < columns.length; colIndex++) {
      for (let panelIndex = 0; panelIndex < columns[colIndex].panels.length; panelIndex++) {
        if (panelId(colIndex, panelIndex) === activeId) {
          return columns[colIndex].panels[panelIndex];
        }
      }
    }
    return null;
  }, [activeId, columns]);

  const parseActive = (id: string): { colIndex: number; panelIndex: number } | null => {
    const match = id.match(/^col-(\d+)-panel-(\d+)$/);
    if (!match) {
      return null;
    }
    return { colIndex: Number(match[1]), panelIndex: Number(match[2]) };
  };

  const handleDragStart = (event: DragStartEvent) => {
    setActiveId(String(event.active.id));
  };

  const handleDragEnd = (event: DragEndEvent) => {
    setActiveId(null);
    const { active, over } = event;
    if (!over) {
      return;
    }

    const source = parseActive(String(active.id));
    if (!source) {
      return;
    }

    const overId = String(over.id);
    let targetCol = source.colIndex;
    let targetIndex = source.panelIndex;

    if (overId.startsWith("column-")) {
      targetCol = Number(overId.replace("column-", ""));
      targetIndex = columns[targetCol]?.panels.length ?? 0;
    } else {
      const target = parseActive(overId);
      if (target) {
        targetCol = target.colIndex;
        targetIndex = target.panelIndex;
      }
    }

    if (targetCol === source.colIndex && targetIndex === source.panelIndex) {
      return;
    }

    const nextColumns = columns.map((column) => ({
      ...column,
      panels: [...column.panels],
    }));
    const [moved] = nextColumns[source.colIndex].panels.splice(source.panelIndex, 1);
    if (source.colIndex === targetCol && targetIndex > source.panelIndex) {
      targetIndex -= 1;
    }
    nextColumns[targetCol].panels.splice(targetIndex, 0, moved);
    onChange(nextColumns);
  };

  return (
    <DndContext sensors={sensors} onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
      <div className="columns-editor">
        {columns.map((column, colIndex) => (
          <ColumnDropZone
            key={`column-${colIndex}`}
            columnIndex={colIndex}
            title={`Column ${colIndex + 1}`}
          >
            {column.panels.map((panel, panelIndex) => {
              const id = panelId(colIndex, panelIndex);
              const globalIndex = globalIndexMap.get(id) ?? 0;
              return (
                <DraggablePanel
                  key={id}
                  id={id}
                  panel={panel}
                  selected={selectedIndex === globalIndex}
                  onSelect={() => onSelect(globalIndex)}
                />
              );
            })}
          </ColumnDropZone>
        ))}
      </div>
      <DragOverlay>
        {activePanel ? (
          <div className="panel-row dragging">
            <div className="meta">
              <strong>{activePanel.title ?? "Untitled"}</strong>
              <span>{activePanel.type}</span>
            </div>
          </div>
        ) : null}
      </DragOverlay>
    </DndContext>
  );
}

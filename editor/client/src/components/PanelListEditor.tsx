import {
  DndContext,
  KeyboardSensor,
  PointerSensor,
  closestCenter,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import {
  SortableContext,
  arrayMove,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import type { DashboardPanel } from "@shared/types";

interface PanelListEditorProps {
  panels: DashboardPanel[];
  selectedIndex: number | null;
  onSelect: (index: number) => void;
  onReorder: (panels: DashboardPanel[]) => void;
}

function SortablePanelRow({
  panel,
  index,
  selected,
  onSelect,
}: {
  panel: DashboardPanel;
  index: number;
  selected: boolean;
  onSelect: () => void;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: `panel-${index}`,
  });

  return (
    <div
      ref={setNodeRef}
      className={`panel-row ${selected ? "selected" : ""} ${isDragging ? "dragging" : ""}`}
      style={{ transform: CSS.Transform.toString(transform), transition }}
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

export function PanelListEditor({
  panels,
  selectedIndex,
  onSelect,
  onReorder,
}: PanelListEditorProps) {
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  );

  const ids = panels.map((_, index) => `panel-${index}`);

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    if (!over || active.id === over.id) {
      return;
    }
    const oldIndex = ids.indexOf(String(active.id));
    const newIndex = ids.indexOf(String(over.id));
    if (oldIndex >= 0 && newIndex >= 0) {
      onReorder(arrayMove(panels, oldIndex, newIndex));
    }
  };

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
      <SortableContext items={ids} strategy={verticalListSortingStrategy}>
        <div className="panel-list">
          {panels.map((panel, index) => (
            <SortablePanelRow
              key={`panel-${index}-${panel.title ?? panel.type}`}
              panel={panel}
              index={index}
              selected={selectedIndex === index}
              onSelect={() => onSelect(index)}
            />
          ))}
        </div>
      </SortableContext>
    </DndContext>
  );
}

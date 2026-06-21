import type { DashboardPage } from "@shared/types";
import { pageLayout } from "./pageUtils";

interface PageSidebarProps {
  pages: DashboardPage[];
  selectedIndex: number;
  onSelect: (index: number) => void;
}

export function PageSidebar({ pages, selectedIndex, onSelect }: PageSidebarProps) {
  return (
    <aside className="sidebar">
      <h2 className="section-title">Pages</h2>
      <div className="page-list">
        {pages.map((page, index) => (
          <button
            key={`${page.id ?? page.title}-${index}`}
            type="button"
            className={`page-button ${index === selectedIndex ? "active" : ""}`}
            onClick={() => onSelect(index)}
          >
            {page.title}
            <small>{pageLayout(page)}</small>
          </button>
        ))}
      </div>
    </aside>
  );
}

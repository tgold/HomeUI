import type { DashboardColumn, DashboardPage, DashboardPanel } from "@shared/types";

export function pageLayout(page: DashboardPage): string {
  return page.layout ?? "columns";
}

export function isColumnsLayout(page: DashboardPage): boolean {
  return pageLayout(page) === "columns";
}

export function getPagePanels(page: DashboardPage): DashboardPanel[] {
  if (isColumnsLayout(page)) {
    const columns = getPageColumns(page);
    return columns.flatMap((column) => column.panels);
  }
  return page.panels ?? [];
}

export function getPageColumns(page: DashboardPage): DashboardColumn[] {
  if (!isColumnsLayout(page)) {
    return [];
  }
  const columns = page.columns;
  if (Array.isArray(columns)) {
    return columns as DashboardColumn[];
  }
  return [];
}

export function setPagePanels(page: DashboardPage, panels: DashboardPanel[]): DashboardPage {
  if (isColumnsLayout(page)) {
    return page;
  }
  return { ...page, panels };
}

export function setPageColumns(page: DashboardPage, columns: DashboardColumn[]): DashboardPage {
  return { ...page, columns };
}

export function updatePageAt(
  config: { pages: DashboardPage[] },
  pageIndex: number,
  page: DashboardPage,
): { pages: DashboardPage[] } {
  const pages = [...config.pages];
  pages[pageIndex] = page;
  return { ...config, pages };
}

export function panelKey(pageIndex: number, panelIndex: number, suffix = ""): string {
  return `${pageIndex}-${panelIndex}${suffix}`;
}

export function cloneConfig<T>(value: T): T {
  return structuredClone(value);
}

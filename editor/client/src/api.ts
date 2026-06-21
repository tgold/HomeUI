import type { DashboardConfig, ValidationResult } from "@shared/types";

export interface MetaInfo {
  configPath: string;
  assetsDir: string;
}

export async function fetchConfig(): Promise<DashboardConfig> {
  const response = await fetch("/api/config");
  if (!response.ok) {
    throw new Error("Failed to load dashboard config");
  }
  return response.json();
}

export async function fetchMeta(): Promise<MetaInfo> {
  const response = await fetch("/api/meta");
  if (!response.ok) {
    throw new Error("Failed to load editor metadata");
  }
  return response.json();
}

export async function saveConfig(config: DashboardConfig): Promise<ValidationResult> {
  const response = await fetch("/api/config", {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(config),
  });
  return response.json();
}

export async function validateConfig(config: DashboardConfig): Promise<ValidationResult> {
  const response = await fetch("/api/validate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(config),
  });
  return response.json();
}

export function assetUrl(imageSource: string): string {
  if (!imageSource) {
    return "";
  }
  if (imageSource.includes("://") || imageSource.startsWith("qrc:")) {
    return imageSource;
  }
  return `/api/assets/${encodeURIComponent(imageSource)}`;
}

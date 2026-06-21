import path from "node:path";
import { fileURLToPath } from "node:url";

const serverDir = path.dirname(fileURLToPath(import.meta.url));
const editorRoot = path.resolve(serverDir, "..");
const repoRoot = path.resolve(editorRoot, "..");

export interface EditorPaths {
  repoRoot: string;
  configPath: string;
  assetsDir: string;
  validatorScript: string;
  clientDist: string;
}

export function resolveEditorPaths(): EditorPaths {
  const configPath = process.env.HOMEUI_CONFIG
    ? path.resolve(process.env.HOMEUI_CONFIG)
    : path.join(repoRoot, "config", "dashboard.json");

  return {
    repoRoot,
    configPath,
    assetsDir: path.join(repoRoot, "assets"),
    validatorScript: path.join(repoRoot, "scripts", "validate-dashboard.py"),
    clientDist: path.join(editorRoot, "client", "dist"),
  };
}

export const editorHost = process.env.EDITOR_HOST ?? "127.0.0.1";
export const editorPort = Number(process.env.EDITOR_PORT ?? 5174);

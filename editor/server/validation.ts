import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import type { ValidationResult } from "../shared/types.js";
import { resolveEditorPaths } from "./config.js";

async function runValidator(configPath: string): Promise<ValidationResult> {
  const { validatorScript } = resolveEditorPaths();
  return new Promise((resolve) => {
    const child = spawn("python3", [validatorScript, configPath], {
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("close", (code) => {
      const output = `${stdout}\n${stderr}`.trim();
      if (code === 0) {
        const pageMatch = output.match(/Pages:\s+(\d+)/);
        const panelMatch = output.match(/Panels:\s+(\d+)/);
        resolve({
          ok: true,
          errors: [],
          pageCount: pageMatch ? Number(pageMatch[1]) : undefined,
          panelCount: panelMatch ? Number(panelMatch[1]) : undefined,
        });
        return;
      }

      const errors = output
        .split("\n")
        .map((line) => line.trim())
        .filter((line) => line.startsWith("- "))
        .map((line) => line.slice(2));

      resolve({
        ok: false,
        errors: errors.length > 0 ? errors : [output || "Validation failed"],
      });
    });
  });
}

export async function validateConfigFile(configPath: string): Promise<ValidationResult> {
  return runValidator(configPath);
}

export async function validateConfigObject(config: unknown): Promise<ValidationResult> {
  const tempPath = path.join(
    os.tmpdir(),
    `homeui-dashboard-${Date.now()}-${Math.random().toString(36).slice(2)}.json`,
  );
  await fs.writeFile(tempPath, JSON.stringify(config, null, 2), "utf-8");
  try {
    return await runValidator(tempPath);
  } finally {
    await fs.unlink(tempPath).catch(() => undefined);
  }
}

export async function saveConfig(
  config: unknown,
  configPath: string,
): Promise<ValidationResult> {
  const validation = await validateConfigObject(config);
  if (!validation.ok) {
    return validation;
  }
  await fs.writeFile(configPath, `${JSON.stringify(config, null, 2)}\n`, "utf-8");
  return validateConfigFile(configPath);
}

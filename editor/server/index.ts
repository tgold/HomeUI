import express from "express";
import fs from "node:fs/promises";
import path from "node:path";
import { editorHost, editorPort, resolveEditorPaths } from "./config.js";
import { saveConfig, validateConfigFile, validateConfigObject } from "./validation.js";

const paths = resolveEditorPaths();
const app = express();
app.use(express.json({ limit: "20mb" }));

app.get("/api/config", async (_req, res) => {
  try {
    const raw = await fs.readFile(paths.configPath, "utf-8");
    res.json(JSON.parse(raw));
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : "Unable to read config",
    });
  }
});

app.put("/api/config", async (req, res) => {
  try {
    const result = await saveConfig(req.body, paths.configPath);
    if (!result.ok) {
      res.status(400).json(result);
      return;
    }
    res.json(result);
  } catch (error) {
    res.status(500).json({
      ok: false,
      errors: [error instanceof Error ? error.message : "Unable to save config"],
    });
  }
});

app.post("/api/validate", async (req, res) => {
  try {
    const result = await validateConfigObject(req.body);
    res.json(result);
  } catch (error) {
    res.status(500).json({
      ok: false,
      errors: [error instanceof Error ? error.message : "Validation failed"],
    });
  }
});

app.get("/api/meta", (_req, res) => {
  res.json({
    configPath: paths.configPath,
    assetsDir: paths.assetsDir,
  });
});

app.use("/api/assets", async (req, res) => {
  const rel = decodeURIComponent(req.path.replace(/^\//, ""));
  if (!rel || rel.includes("..")) {
    res.status(400).json({ error: "Invalid asset path" });
    return;
  }

  const candidates = [
    path.join(paths.assetsDir, rel),
    path.join(path.dirname(paths.configPath), rel),
  ];

  for (const candidate of candidates) {
    try {
      await fs.access(candidate);
      res.sendFile(candidate);
      return;
    } catch {
      // try next candidate
    }
  }

  res.status(404).json({ error: "Asset not found" });
});

if (process.env.NODE_ENV === "production") {
  app.use(express.static(paths.clientDist));
  app.get("*", (_req, res) => {
    res.sendFile(path.join(paths.clientDist, "index.html"));
  });
}

app.listen(editorPort, editorHost, () => {
  console.log(`HomeUI dashboard editor API on http://${editorHost}:${editorPort}`);
  console.log(`Config: ${paths.configPath}`);
});

export default app;

import express from "express";
import cors from "cors";
import path from "node:path";
import fs from "node:fs";
import { spawn } from "node:child_process";
import multer from "multer";
import { cargarPcdDesdeJson, buscarSeries, agruparPorFondo, obtenerPorCodigo } from "../data/loadEssaludPcd.js";

const app = express();
app.use(cors());
app.use(express.json());

// upload middleware — store temporarily into repo data/ so the existing
// Python extractor can find the file (the extractor looks for
// data/ESSALUD-PCD-ANEXO-2-TABLA.pdf by default).
const repoDataDir = path.resolve(process.cwd(), "data");
fs.mkdirSync(repoDataDir, { recursive: true });
const expectedPdfName = "ESSALUD-PCD-ANEXO-2-TABLA.pdf";
const upload = multer({ dest: path.join(repoDataDir, "uploads") });

// Simple single-run lock — avoid concurrent extractor runs
let extractionInProgress = false;
let lastExtractionSummary: any = null;

// Data loader helper (keeps series in module scope for simplicity)
const DATA = path.resolve(process.cwd(), "data", "essalud_pcd_anexo02.full.json");
let series = cargarPcdDesdeJson(DATA);

app.get("/health", (_req, res) => res.json({ ok: true, series: series.length }));

app.get("/series", (req, res) => {
  const { q, fondo } = req.query as { q?: string; fondo?: string };
  let out = series;
  if (q) out = buscarSeries(out, q);
  if (fondo) out = out.filter(s => s.fondo.toLowerCase().includes(fondo.toLowerCase()));
  res.json(out);
});

app.get("/series/:codigo", (req, res) => {
  const s = obtenerPorCodigo(series, req.params.codigo);
  if (!s) return res.status(404).json({ error: "No encontrado" });
  res.json(s);
});

app.get("/fondos", (_req, res) => {
  const by = agruparPorFondo(series);
  const resumen = Object.fromEntries(Object.entries(by).map(([k, arr]) => [k, arr.length]));
  res.json(resumen);
});

app.post("/reload", (_req, res) => {
  try {
    series = cargarPcdDesdeJson(DATA);
    return res.json({ reloaded: true, count: series.length, path: DATA });
  } catch (err: any) {
    return res.status(500).json({ reloaded: false, error: String(err) });
  }
});


// POST /upload
// Accepts multipart/form-data with field `file` (the PDF). Saves the uploaded
// PDF into `data/ESSALUD-PCD-ANEXO-2-TABLA.pdf`, runs the Python extractor
// `tools/run_user_extract.py`, waits for completion, then reloads the in-memory
// dataset and returns the extractor summary.
app.post("/upload", upload.single("file"), async (req, res) => {
  const uploadedFile = (req as any).file;
  if (!uploadedFile) return res.status(400).json({ error: "No file uploaded (field 'file')" });

  if (extractionInProgress) {
    // Simple rejection to keep it predictable; clients can retry later.
    // We could implement a queue in a later iteration.
    return res.status(429).json({ error: "Extraction already in progress" });
  }

  extractionInProgress = true;
  const uploadedPath = uploadedFile.path;
  const targetPath = path.join(repoDataDir, expectedPdfName);

  try {
    // Move the uploaded file into the expected name so the existing extractor
    // will find it when it runs. Overwrite if exists.
    await fs.promises.copyFile(uploadedPath, targetPath);
    // Optionally remove the temporary upload file
    try { await fs.promises.unlink(uploadedPath); } catch { /* ignore */ }

    // Determine python executable
    const pythonExe = process.env.PYTHON || process.env.PYTHON3 || "python";
    const scriptPath = path.resolve(process.cwd(), "tools", "run_user_extract.py");

    // Spawn the extractor and capture stdout/stderr
    const child = spawn(pythonExe, [scriptPath], { shell: false });

    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (b) => { stdout += b.toString(); });
    child.stderr.on("data", (b) => { stderr += b.toString(); });

    const exitCode: number = await new Promise((resolve) => {
      child.on("close", (code) => resolve(code === null ? 1 : code));
    });

    if (exitCode !== 0) {
      extractionInProgress = false;
      return res.status(500).json({
        error: "Extractor failed",
        exitCode,
        stderr: stderr.slice(0, 32_000),
      });
    }

  // The extractor prints a JSON blob; try to parse it from stdout
    let parsed: any = null;
    try {
      parsed = JSON.parse(stdout);
    } catch {
      // If not pure JSON, try to find a JSON object inside
      const idx = stdout.indexOf("{\n");
      if (idx >= 0) {
        try { parsed = JSON.parse(stdout.slice(idx)); } catch { parsed = null; }
      }
    }

    // Reload in-memory data
    try {
      series = cargarPcdDesdeJson(DATA);
    } catch (err: any) {
      extractionInProgress = false;
      return res.status(500).json({ error: "Reload after extraction failed", details: String(err) });
    }
    // Store last summary for monitoring
    lastExtractionSummary = parsed?.summary ?? null;

    extractionInProgress = false;
    return res.json({ extracted: true, summary: lastExtractionSummary, reloaded: true, count: series.length });
  } catch (err: any) {
    extractionInProgress = false;
    return res.status(500).json({ error: String(err) });
  }
});


app.get('/status', (_req, res) => {
  res.json({ extractionInProgress, lastExtractionSummary, seriesCount: series.length });
});

// Export a programmatic start function so we can run integration tests that start
// the server in-process and query it without external networking issues.
export function startServer(port = Number(process.env.PORT || 0), host = '127.0.0.1') {
  return new Promise<import("node:http").Server>((resolve, reject) => {
    try {
      const server = app.listen(port, host, () => {
        // server.address() can be string or AddressInfo; guard for AddressInfo
        resolve(server as import("node:http").Server);
      });
      server.on('error', (err) => reject(err));
    } catch (err) {
      reject(err);
    }
  });
}

export default app;



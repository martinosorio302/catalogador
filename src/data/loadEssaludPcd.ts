import fs from "node:fs";
import path from "node:path";
import { SerieDocumental, validarSerie } from "../domain/retencion.js";

export function cargarPcdDesdeJson(ruta: string): SerieDocumental[] {
  const full = path.resolve(ruta);
  const raw = fs.readFileSync(full, "utf8");
  const arr = JSON.parse(raw) as SerieDocumental[];

  // Sanitizado + validación
  const out: SerieDocumental[] = [];
  const errores: { index: number; errores: string[] }[] = [];

  arr.forEach((s, i) => {
    const copy: SerieDocumental = {
      ...s,
      fondo: (s.fondo || "").toString().trim(),
      codigo: (s.codigo || "").toString().trim().toUpperCase(),
      titulo: (s.titulo || "").toString().trim(),
      valor: (s.valor || "").toString().toUpperCase() as any,
      retencion: {
        gestion: Number(s.retencion?.gestion ?? 0),
        periferico: Number(s.retencion?.periferico ?? 0),
        central: Number(s.retencion?.central ?? 0),
        total: Number(s.retencion?.total ?? 0),
      },
    };
    const errs = validarSerie(copy);
    if (errs.length) errores.push({ index: i, errores: errs });
    out.push(copy);
  });

  if (errores.length) {
    const resumen = errores
      .map(e => `#${e.index}: ${e.errores.join("; ")}`)
      .join("\n");
    console.warn("Advertencias al cargar PCD:\n" + resumen);
  }
  return out;
}

// Facilidad: agrupar por fondo → series[]
export function agruparPorFondo(series: SerieDocumental[]): Record<string, SerieDocumental[]> {
  return series.reduce((acc, s) => {
    acc[s.fondo] ??= [];
    acc[s.fondo].push(s);
    return acc;
  }, {} as Record<string, SerieDocumental[]>);
}

export function buscarSeries(series: SerieDocumental[], q: string): SerieDocumental[] {
  const ql = q.toLowerCase();
  return series.filter(s =>
    s.codigo.toLowerCase().includes(ql) ||
    s.titulo.toLowerCase().includes(ql) ||
    s.fondo.toLowerCase().includes(ql));
}

export function obtenerPorCodigo(series: SerieDocumental[], codigo: string): SerieDocumental | undefined {
  const key = codigo.trim().toUpperCase();
  return series.find(s => s.codigo === key);
}

// Consulta de retención por código
export function obtenerRetencionPorCodigo(series: SerieDocumental[], codigo: string) {
  const key = codigo.trim().toUpperCase();
  return series.find(s => s.codigo === key)?.retencion ?? null;
}

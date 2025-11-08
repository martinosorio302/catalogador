import { SerieDocumental } from "./retencion";

export function validarSerie(s: SerieDocumental): string[] {
  const errs: string[] = [];
  if (!s.fondo?.trim()) errs.push("fondo vacío");
  if (!/^[A-Z]{2,5}\/\d{2}$/i.test(s.codigo)) errs.push(`codigo inválido: ${s.codigo}`);
  if (!s.titulo?.trim()) errs.push("titulo vacío");
  if (s.valor !== "PERMANENTE" && s.valor !== "TEMPORAL") errs.push("valor debe ser PERMANENTE|TEMPORAL");

  if (!s.retencion) errs.push("retencion ausente");
  else {
    const r = s.retencion;
    ["gestion","periferico","central","total"].forEach(k => {
      if (typeof (r as any)[k] !== "number" || (r as any)[k] < 0) errs.push(`retencion.${k} inválido`);
    });
    // Si deseas forzar coherencia:
    // const suma = r.gestion + r.periferico + r.central;
    // if (r.total !== suma) errs.push(`retencion.total distinto a suma columnas (${r.total}≠${suma})`);
  }
  return errs;
}

export function validarUnicidadCodigos(series: SerieDocumental[]): string[] {
  const errs: string[] = [];
  const map = new Map<string, number>();
  for (const s of series) {
    const k = s.codigo.toUpperCase();
    map.set(k, (map.get(k) || 0) + 1);
  }
  for (const [k, v] of map.entries()) {
    if (v > 1) errs.push(`codigo duplicado: ${k} (x${v})`);
  }
  return errs;
}

export function validar(series: SerieDocumental[]): string[] {
  const errs: string[] = [];
  series.forEach((s, i) => {
    const e = validarSerie(s);
    if (e.length) errs.push(`#${i} (${s.codigo}): ${e.join("; ")}`);
  });
  errs.push(...validarUnicidadCodigos(series));
  return errs;
}

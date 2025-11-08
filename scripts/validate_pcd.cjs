const fs = require('fs');
const path = require('path');

function validarSerie(s) {
  const errs = [];
  if (!s.fondo || !s.fondo.toString().trim()) errs.push('fondo vacío');
  if (!/^[A-Z]{2,5}\/\d{2}$/i.test(s.codigo || '')) errs.push(`codigo inválido: ${s.codigo}`);
  if (!s.titulo || !s.titulo.toString().trim()) errs.push('titulo vacío');
  if (s.valor !== 'PERMANENTE' && s.valor !== 'TEMPORAL') errs.push('valor debe ser PERMANENTE|TEMPORAL');

  const r = s.retencion;
  if (!r) errs.push('retencion ausente');
  else {
    if (typeof r.gestion !== 'number' || r.gestion < 0) errs.push('retencion.gestion inválido');
    if (typeof r.periferico !== 'number' || r.periferico < 0) errs.push('retencion.periferico inválido');
    if (typeof r.central !== 'number' || r.central < 0) errs.push('retencion.central inválido');
    if (typeof r.total !== 'number' || r.total < 0) errs.push('retencion.total inválido');
  }
  return errs;
}

function validarUnicidad(series) {
  const map = new Map();
  for (const s of series) {
    const k = (s.codigo || '').toString().toUpperCase();
    map.set(k, (map.get(k) || 0) + 1);
  }
  const dup = [];
  for (const [k, v] of map.entries()) if (v > 1) dup.push({ codigo: k, count: v });
  return dup;
}

function main() {
  const arg = process.argv[2];
  const input = arg ? path.resolve(arg) : path.resolve(__dirname, '..', 'data', 'essalud_pcd_anexo02.sample.json');
  if (!fs.existsSync(input)) {
    console.error('Input file not found:', input);
    process.exit(2);
  }
  const raw = fs.readFileSync(input, 'utf8');
  let arr = [];
  try { arr = JSON.parse(raw); } catch (e) { console.error('Error parseando JSON:', e.message); process.exit(3); }

  // Normalize minimal like the TS loader
  arr = arr.map(s => ({
    ...s,
    fondo: (s.fondo || '').toString().trim(),
    codigo: (s.codigo || '').toString().trim().toUpperCase(),
    titulo: (s.titulo || '').toString().trim(),
    valor: (s.valor || '').toString().toUpperCase(),
    retencion: {
      gestion: Number(s.retencion?.gestion ?? 0),
      periferico: Number(s.retencion?.periferico ?? 0),
      central: Number(s.retencion?.central ?? 0),
      total: Number(s.retencion?.total ?? 0),
    }
  }));

  const results = arr.map(s => ({ codigo: s.codigo, errores: validarSerie(s) }));
  const duplicates = validarUnicidad(arr);

  const out = {
    input: input,
    total_series: arr.length,
    results,
    duplicates,
    errors_count: results.reduce((acc, r) => acc + (r.errores.length), 0) + duplicates.length
  };

  const outDir = path.resolve(__dirname, '..', 'outputs');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, 'validacion.json');
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2), 'utf8');
  console.log('Reporte escrito en', outPath);
}

if (require.main === module) main();

import { cargarPcdDesdeJson, buscarSeries, obtenerPorCodigo, agruparPorFondo } from "./data/loadEssaludPcd.js";

const DATA = "./data/essalud_pcd_anexo02.full.json";
const series = cargarPcdDesdeJson(DATA);

console.log(`Series cargadas: ${series.length}`);

const arg = process.argv.slice(2).join(" ");
if (arg) {
  if (/^[A-Z]{2,5}\/\d{2}$/i.test(arg)) {
    console.log("Consulta por código:", arg);
    console.log(obtenerPorCodigo(series, arg));
  } else {
    console.log(`Búsqueda textual: "${arg}"`);
    console.table(buscarSeries(series, arg).slice(0, 10));
  }
} else {
  const by = agruparPorFondo(series);
  const top = Object.entries(by).sort((a: any, b: any) => b[1].length - a[1].length).slice(0, 10);
  console.log("Top 10 fondos por cantidad de series:");
  for (const [f, arr] of top) console.log(`- ${f}: ${arr.length}`);
}


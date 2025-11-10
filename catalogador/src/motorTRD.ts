import { INDICE_TOKENS } from "./index.tokens";
import type { DocumentoBase } from "./types";

function normaliza(s?: string): string {
  if (!s) return "";
  return s.normalize("NFD").replace(/\p{Diacritic}/gu, "").toUpperCase();
}

function textoIndice(asuntoUnidad?: string, tituloDoc?: string, productor?: string) {
  return [asuntoUnidad, tituloDoc, productor].filter(Boolean).map(normaliza).join(" | ");
}

function tokensIncluidos(texto: string, tokens: string[]) {
  return tokens.every((t) => texto.includes(normaliza(t)));
}

function clasificarPorTokens(asuntoUnidad?: string, tituloDoc?: string, productor?: string): string | undefined {
  const txt = textoIndice(asuntoUnidad, tituloDoc, productor);
  for (const r of INDICE_TOKENS) {
    if (tokensIncluidos(txt, r.tokens)) return r.codes[0];
  }
  return undefined;
}

export function aplicarReglasTRD(items: DocumentoBase[]): (DocumentoBase & { codigoSerie?: string; temporalidad?: string; plazoConservacionAnios?: number; destinoFinal?: string; observaciones?: string })[] {
  return items.map((d) => {
    const codeTok = clasificarPorTokens(d.productor || d.tituloAsunto || d.serie, d.tituloAsunto, d.productor);
    // Simple matching: if serie already matches a known token, prefer it
    const entryCode = codeTok ?? undefined;

    let temporalidad: 'Permanente' | 'Temporal' = 'Temporal';
    let destino = 'Eliminación';
    let plazo = d.plazoConservacionAnios ?? 8;
    let observaciones = '';

    if (entryCode) {
      // rudimentary mapping for demo — expand with full TRD table elsewhere
      if (entryCode.startsWith('CODI') || entryCode.startsWith('PREJ')) {
        temporalidad = 'Permanente';
        destino = 'Conservación Permanente';
        plazo = 30;
      } else if (entryCode.startsWith('COIN') || entryCode.startsWith('COCE')) {
        temporalidad = 'Temporal';
        plazo = 15;
        destino = (plazo >= 5) ? 'Transferencia al Archivo Central' : 'Eliminación';
      }
      observaciones = `${entryCode} · Asignación por índice`; 
    } else {
      // fallback
      temporalidad = d.temporalidad ?? 'Temporal';
      destino = d.destinoFinal ?? destino;
    }

    return {
      ...d,
      codigoSerie: entryCode,
      temporalidad,
      plazoConservacionAnios: plazo,
      destinoFinal: destino,
      observaciones: observaciones || d.observaciones,
    };
  });
}

export function simularAnalisisPDF(nombre: string) {
  // small helper to produce demo items and classify them
  const { simulateAnalysis } = require('./simulate') as { simulateAnalysis: (n: string) => DocumentoBase[] };
  const items = simulateAnalysis(nombre);
  return aplicarReglasTRD(items);
}

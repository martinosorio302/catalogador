import type { TokenRule } from "./types";

// Índice alfabético (Anexo 3) — tokens -> códigos TRD
export const INDICE_TOKENS: TokenRule[] = [
  { tokens: ["ACTAS", "CONSEJO DIRECTIVO"], codes: ["CODI/01"] },
  { tokens: ["CORRESPONDENCIA", "CONSEJO DIRECTIVO"], codes: ["CODI/02"] },
  { tokens: ["RESOLUCION", "PRESIDENCIA EJECUTIVA"], codes: ["PREJ/01"] },
  { tokens: ["PRONUNCIAMIENTO", "PRESIDENCIA EJECUTIVA"], codes: ["PREJ/02"] },
  { tokens: ["CORRESPONDENCIA", "PRESIDENCIA EJECUTIVA"], codes: ["PREJ/03"] },
  { tokens: ["ACCIONES", "CONTROL"], codes: ["COIN/02"] },
  { tokens: ["ACTIVIDADES", "CONTROL"], codes: ["COIN/03"] },
  { tokens: ["QUEJAS", "DENUNCIAS"], codes: ["COCE/01", "COD1/01"] },
  { tokens: ["HOJAS", "EVALUACIONES"], codes: ["COCE/02", "COD1/02"] },
  { tokens: ["PAPELES", "TRABAJO"], codes: ["COCE/03", "COD1/03"] },
  { tokens: ["CORRESPONDENCIA", "CONTROL INSTITUCIONAL"], codes: ["COIN/04"] },
  // Amplíe este índice con el Anexo 3 completo según necesidad.
];

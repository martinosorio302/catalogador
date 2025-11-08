import type { TRDEntry } from "./types"

export const TRD_TABLA: TRDEntry[] = [
  // Consejo Directivo
  { codigo: "CODI/01", serie: "ACTAS DE SESIONES", valor: "Permanente", ag: 2, ap: 0, oaa: 28, total: 30, unidad: "Consejo Directivo", descripcion: "Actas y acuerdos de sesiones del Consejo Directivo." },
  { codigo: "CODI/02", serie: "CORRESPONDENCIA",   valor: "Temporal",   ag: 2, ap: 0, oaa: 6,  total: 8,  unidad: "Consejo Directivo", descripcion: "Cartas, oficios, informes y comunicaciones oficiales." },

  // Presidencia Ejecutiva
  { codigo: "PREJ/01", serie: "RESOLUCIONES",      valor: "Permanente", ag: 2, ap: 0, oaa: 28, total: 30, unidad: "Presidencia Ejecutiva", descripcion: "Resoluciones con antecedentes y notificación." },
  { codigo: "PREJ/02", serie: "PRONUNCIAMIENTOS",  valor: "Permanente", ag: 2, ap: 0, oaa: 28, total: 30, unidad: "Presidencia Ejecutiva", descripcion: "Pronunciamientos sobre observaciones de bases." },
  { codigo: "PREJ/03", serie: "CORRESPONDENCIA",   valor: "Temporal",   ag: 2, ap: 0, oaa: 6,  total: 8,  unidad: "Presidencia Ejecutiva", descripcion: "Cartas, oficios e informes de Presidencia." },

  // Órgano de Control Institucional
  { codigo: "COIN/01", serie: "RESOLUCIONES JEFATURALES", valor: "Permanente", ag: 2, ap: 8, oaa: 20, total: 30, unidad: "OCI", descripcion: "Resoluciones del OCI con antecedentes." },
  { codigo: "COIN/02", serie: "ACCIONES DE CONTROL",      valor: "Temporal",   ag: 2, ap: 8, oaa: 5,  total: 15, unidad: "OCI", descripcion: "Auditorías de control posterior e informes." },
  { codigo: "COIN/03", serie: "ACTIVIDADES DE CONTROL",   valor: "Temporal",   ag: 2, ap: 8, oaa: 5,  total: 15, unidad: "OCI", descripcion: "Control preventivo, veedurías, visitas." },
  { codigo: "COIN/04", serie: "CORRESPONDENCIA",          valor: "Temporal",   ag: 2, ap: 8, oaa: 2,  total: 12, unidad: "OCI", descripcion: "Cartas y oficios de OCI." },

  // Control Centralizado
  { codigo: "COCE/01", serie: "EXPEDIENTES DE QUEJAS Y DENUNCIAS", valor: "Temporal", ag: 2, ap: 8, oaa: 5, total: 15, unidad: "Control Centralizado", descripcion: "Quejas y denuncias contra servidores." },
  { codigo: "COCE/02", serie: "HOJAS DE EVALUACIONES",              valor: "Temporal", ag: 2, ap: 8, oaa: 5, total: 15, unidad: "Control Centralizado", descripcion: "Hojas informativas/evaluativas." },
  { codigo: "COCE/03", serie: "PAPELES DE TRABAJO",                 valor: "Temporal", ag: 2, ap: 8, oaa: 5, total: 15, unidad: "Control Centralizado", descripcion: "Papeles y matrices de auditoría." },
  { codigo: "COCE/04", serie: "CORRESPONDENCIA",                    valor: "Temporal", ag: 2, ap: 8, oaa: 2, total: 12, unidad: "Control Centralizado", descripcion: "Cartas, oficios e informes." },

  // Control Centralizado I / II
  { codigo: "COC1/01", serie: "CORRESPONDENCIA", valor: "Temporal", ag: 2, ap: 8, oaa: 2, total: 12, unidad: "Control Centralizado I", descripcion: "Correspondencia CC-I." },
  { codigo: "COC2/01", serie: "CORRESPONDENCIA", valor: "Temporal", ag: 2, ap: 8, oaa: 2, total: 12, unidad: "Control Centralizado II", descripcion: "Correspondencia CC-II." },

  // Control Descentralizado I (ejemplos)
  { codigo: "COD1/01", serie: "EXPEDIENTES DE QUEJAS Y DENUNCIAS", valor: "Temporal", ag: 2, ap: 8, oaa: 5, total: 15, unidad: "Control Descentralizado I", descripcion: "Quejas/denuncias territoriales." },
  { codigo: "COD1/02", serie: "HOJAS DE EVALUACIONES",             valor: "Temporal", ag: 2, ap: 8, oaa: 5, total: 15, unidad: "Control Descentralizado I", descripcion: "Hojas informativas." },
  { codigo: "COD1/03", serie: "PAPELES DE TRABAJO",                 valor: "Temporal", ag: 2, ap: 8, oaa: 5, total: 15, unidad: "Control Descentralizado I", descripcion: "Papeles de trabajo." },
  { codigo: "COD1/04", serie: "CORRESPONDENCIA",                    valor: "Temporal", ag: 2, ap: 8, oaa: 2, total: 12, unidad: "Control Descentralizado I", descripcion: "Correspondencia." },

  // Patrimonio Documental (ejemplo)
  { codigo: "PATR/ACT", serie: "ACTAS", valor: "Permanente", ag: 0, ap: 0, oaa: 0, total: 0, unidad: "Archivo Central", descripcion: "Actas patrimoniales y de valor histórico." }
]

/*
  TRD / PCD knowledge module
  - Exports: aplicarReglasTRD, normaliza, clasificarPorTokens, TRD_TABLA, INVENTARIO_DESCRIPCION
  - Self-test when executed with `node trd.js`
*/
'use strict';

// 1) Tabla General de Retención (ANEXO 02)
const TRD_TABLA = [
  { code: 'CODI/01', titulo: 'ACTAS DE SESIONES', valor: 'Permanente', ag: 2, ap: 0, oaa: 28, total: 30, asunto: 'CONSEJO DIRECTIVO' },
  { code: 'CODI/02', titulo: 'CORRESPONDENCIA',    valor: 'Temporal',   ag: 2, ap: 0, oaa: 6,  total: 8,  asunto: 'CONSEJO DIRECTIVO' },
  { code: 'PREJ/01', titulo: 'RESOLUCIONES',       valor: 'Permanente', ag: 2, ap: 0, oaa: 28, total: 30, asunto: 'PRESIDENCIA EJECUTIVA' },
  { code: 'PREJ/02', titulo: 'PRONUNCIAMIENTOS',   valor: 'Permanente', ag: 2, ap: 0, oaa: 28, total: 30, asunto: 'PRESIDENCIA EJECUTIVA' },
  { code: 'PREJ/03', titulo: 'CORRESPONDENCIA',    valor: 'Temporal',   ag: 2, ap: 0, oaa: 6,  total: 8,  asunto: 'PRESIDENCIA EJECUTIVA' },
  { code: 'COIN/01', titulo: 'RESOLUCIONES JEFATURALES', valor: 'Permanente', ag: 2, ap: 8, oaa: 20, total: 30, asunto: 'CONTROL INSTITUCIONAL' },
  { code: 'COIN/02', titulo: 'ACCIONES DE CONTROL',      valor: 'Temporal',   ag: 2, ap: 8, oaa: 5,  total: 15, asunto: 'CONTROL INSTITUCIONAL' },
  { code: 'COIN/03', titulo: 'ACTIVIDADES DE CONTROL',   valor: 'Temporal',   ag: 2, ap: 8, oaa: 5,  total: 15, asunto: 'CONTROL INSTITUCIONAL' },
  { code: 'COIN/04', titulo: 'CORRESPONDENCIA',          valor: 'Temporal',   ag: 2, ap: 8, oaa: 2,  total: 12, asunto: 'CONTROL INSTITUCIONAL' },
  { code: 'COCA/01', titulo: 'CORRESPONDENCIA',          valor: 'Temporal',   ag: 2, ap: 8, oaa: 2,  total: 12, asunto: 'CONTROL DE CALIDAD' },
  { code: 'AGMC/01', titulo: 'INFORMES DE SOCIEDADES AUDITORAS',          valor: 'Temporal', ag: 2, ap: 8, oaa: 5, total: 15, asunto: 'APOYO A LA GESTION Y MEDIDAS CORRECTIVAS' },
  { code: 'AGMC/02', titulo: 'INFORMES DE SEGUIMIENTOS DE MEDIDAS CORRECTIVAS', valor: 'Temporal', ag: 2, ap: 8, oaa: 5, total: 15, asunto: 'APOYO A LA GESTION Y MEDIDAS CORRECTIVAS' },
  { code: 'AGMC/03', titulo: 'VEEDURIAS',                            valor: 'Temporal', ag: 2, ap: 8, oaa: 5, total: 15, asunto: 'APOYO A LA GESTION Y MEDIDAS CORRECTIVAS' },
  { code: 'AGMC/04', titulo: 'CORRESPONDENCIA',                      valor: 'Temporal', ag: 2, ap: 8, oaa: 2, total: 12, asunto: 'APOYO A LA GESTION Y MEDIDAS CORRECTIVAS' },
  { code: 'APGE/01', titulo: 'CORRESPONDENCIA', valor: 'Temporal', ag: 2, ap: 8, oaa: 2, total: 12, asunto: 'APOYO A LA GESTION' },
  { code: 'SEMC/01', titulo: 'CORRESPONDENCIA', valor: 'Temporal', ag: 2, ap: 8, oaa: 2, total: 12, asunto: 'SEGUIMIENTO DE MEDIDAS CORRECTIVAS' },
  { code: 'COCE/01', titulo: 'EXPEDIENTES DE QUEJAS Y DENUNCIAS', valor: 'Temporal', ag: 2, ap: 8, oaa: 5, total: 15, asunto: 'CONTROL CENTRALIZADO' },
  { code: 'COCE/02', titulo: 'HOJAS DE EVALUACIONES',             valor: 'Temporal', ag: 2, ap: 8, oaa: 5, total: 15, asunto: 'CONTROL CENTRALIZADO' },
  { code: 'COCE/03', titulo: 'PAPELES DE TRABAJO',                 valor: 'Temporal', ag: 2, ap: 8, oaa: 5, total: 15, asunto: 'CONTROL CENTRALIZADO' },
  { code: 'COCE/04', titulo: 'CORRESPONDENCIA',                    valor: 'Temporal', ag: 2, ap: 8, oaa: 2, total: 12, asunto: 'CONTROL CENTRALIZADO' },
  { code: 'COC1/01', titulo: 'CORRESPONDENCIA', valor: 'Temporal', ag: 2, ap: 8, oaa: 2, total: 12, asunto: 'CONTROL CENTRALIZADO I' },
  { code: 'COC2/01', titulo: 'CORRESPONDENCIA', valor: 'Temporal', ag: 2, ap: 8, oaa: 2, total: 12, asunto: 'CONTROL CENTRALIZADO II' },
  { code: 'COD1/01', titulo: 'EXPEDIENTES DE QUEJAS Y DENUNCIAS', valor: 'Temporal', ag: 2, ap: 8, oaa: 5, total: 15, asunto: 'CONTROL DESCENTRALIZADO I' },
  { code: 'COD1/02', titulo: 'HOJAS DE EVALUACIONES',             valor: 'Temporal', ag: 2, ap: 8, oaa: 5, total: 15, asunto: 'CONTROL DESCENTRALIZADO I' },
  { code: 'COD1/03', titulo: 'PAPELES DE TRABAJO',                 valor: 'Temporal', ag: 2, ap: 8, oaa: 5, total: 15, asunto: 'CONTROL DESCENTRALIZADO I' },
  { code: 'COD1/04', titulo: 'CORRESPONDENCIA',                    valor: 'Temporal', ag: 2, ap: 8, oaa: 2, total: 12, asunto: 'CONTROL DESCENTRALIZADO I' }
];

// 2) Inventario – descripciones oficiales por código (ANEXO 01)
const INVENTARIO_DESCRIPCION = {
  'CODI/01': 'Actas y acuerdos del Consejo Directivo (con antecedentes).',
  'CODI/02': 'Correspondencia del Consejo Directivo (cartas, oficios, informes, etc.).',
  'PREJ/01': 'Resoluciones de la Presidencia Ejecutiva (con antecedentes y notificación).',
  'PREJ/02': 'Pronunciamientos sobre bases y observaciones de procesos de selección.',
  'PREJ/03': 'Correspondencia de la Presidencia Ejecutiva.',
  'COIN/01': 'Resoluciones jefaturales del Órgano de Control Institucional.',
  'COIN/02': 'Acciones de control posterior (estados fin., presupuestarios, gestión, etc.).',
  'COIN/03': 'Actividades/acciones preventivas de control (veedurías, visitas, etc.).',
  'COIN/04': 'Correspondencia del OCI.',
  'COCE/01': 'Expedientes de quejas y denuncias contra servidores públicos.',
  'COCE/02': 'Hojas de evaluaciones/informativas para control preventivo.',
  'COCE/03': 'Papeles de trabajo de acciones de control.'
};

// 3) Índice alfabético – tokens → código (ANEXO 03)
const INDICE_TOKENS = [
  { tokens: ['ACTAS','CONSEJO DIRECTIVO'], codes: ['CODI/01'] },
  { tokens: ['CORRESPONDENCIA','CONSEJO DIRECTIVO'], codes: ['CODI/02'] },
  { tokens: ['RESOLUCION','PRESIDENCIA EJECUTIVA'], codes: ['PREJ/01'] },
  { tokens: ['PRONUNCIAMIENTO','PRESIDENCIA EJECUTIVA'], codes: ['PREJ/02'] },
  { tokens: ['CORRESPONDENCIA','PRESIDENCIA EJECUTIVA'], codes: ['PREJ/03'] },
  { tokens: ['ACCIONES DE CONTROL'], codes: ['COIN/02'] },
  { tokens: ['ACTIVIDADES DE CONTROL'], codes: ['COIN/03'] },
  { tokens: ['QUEJAS','DENUNCIAS'], codes: ['COCE/01','COD1/01'] },
  { tokens: ['HOJAS','EVALUACIONES'], codes: ['COCE/02','COD1/02'] },
  { tokens: ['PAPELES','TRABAJO'], codes: ['COCE/03','COD1/03'] },
  { tokens: ['CORRESPONDENCIA','CONTROL INSTITUCIONAL'], codes: ['COIN/04'] }
];

function normaliza(s) {
  try {
    return (s || '').normalize('NFD').replace(/\p{Diacritic}/gu, '').toUpperCase();
  } catch (err) {
    // Older Node may not support \p{Diacritic}; fallback: strip combining marks by range
    return (s || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toUpperCase();
  }
}

function textoIndice(asuntoUnidad, tituloDoc, productor) {
  return [asuntoUnidad, tituloDoc, productor].filter(Boolean).map(normaliza).join(' | ');
}

function tokensIncluidos(texto, tokens) {
  return tokens.every(t => texto.includes(normaliza(t)));
}

function clasificarPorTokens(asuntoUnidad, tituloDoc, productor) {
  const txt = textoIndice(asuntoUnidad, tituloDoc, productor);
  for (const r of INDICE_TOKENS) {
    if (tokensIncluidos(txt, r.tokens)) return r.codes[0];
  }
  return undefined;
}

function buscarTRDPorCodigo(code) { return TRD_TABLA.find(x => x.code === code); }

function buscarTRDPorAsuntoTitulo(asunto, serieSugerida) {
  const a = normaliza(asunto || '');
  const s = normaliza(serieSugerida || '');
  return TRD_TABLA.find(x => a.includes(normaliza(x.asunto)) && s.includes(normaliza(x.titulo))) || undefined;
}

// Motor final: a partir de (serie, subserie, tipo, título, productor) asigna código, temporalidad, plazos y destino
function aplicarReglasTRD(input) {
  const porAsunto = (input.serie && input.asuntoUnidad) ? buscarTRDPorAsuntoTitulo(input.asuntoUnidad, input.serie) : undefined;
  const codeTok = clasificarPorTokens(input.asuntoUnidad, input.titulo, input.productor);
  const entry = porAsunto || (codeTok ? buscarTRDPorCodigo(codeTok) : undefined);

  if (entry) {
    const temporalidad = entry.valor === 'Permanente' ? 'Permanente' : 'Temporal';
    let destino = temporalidad === 'Permanente' ? 'Conservación Permanente' : 'Eliminación';
    if (temporalidad === 'Temporal' && entry.oaa >= 5) destino = 'Transferencia al Archivo Central';
    return { code: entry.code, tituloSerie: entry.titulo, plazoConservacionAnios: entry.total, temporalidad, destino };
  }

  return { code: undefined, tituloSerie: input.serie || 'Correspondencia', plazoConservacionAnios: 8, temporalidad: 'Temporal', destino: 'Eliminación' };
}

module.exports = {
  TRD_TABLA,
  INVENTARIO_DESCRIPCION,
  INDICE_TOKENS,
  normaliza,
  clasificarPorTokens,
  aplicarReglasTRD,
  buscarTRDPorCodigo,
  buscarTRDPorAsuntoTitulo
};

// Self-test smoke-run when invoked directly
if (require.main === module) {
  console.log('TRD module self-test — running sample classifications');
  const samples = [
    { asuntoUnidad: 'CONSEJO DIRECTIVO', titulo: 'Actas de sesiones', serie: 'Actas' },
    { asuntoUnidad: 'PRESIDENCIA EJECUTIVA', titulo: 'Correspondencia general', serie: 'Correspondencia' },
    { asuntoUnidad: 'CONTROL INSTITUCIONAL', titulo: 'Acciones de control posterior', serie: 'Acciones' },
    { asuntoUnidad: 'CONTROL CENTRALIZADO', titulo: 'Expedientes de quejas y denuncias', serie: 'Quejas' },
    { asuntoUnidad: 'UNIDAD DESCONOCIDA', titulo: 'Carta de presentación', serie: 'Correspondencia' }
  ];

  for (const s of samples) {
    const out = aplicarReglasTRD(s);
    console.log('\nInput:', s);
    console.log('Result:', out);
    if (out.code) {
      console.log('Descripción inventario:', INVENTARIO_DESCRIPCION[out.code] || '(no disponible)');
    }
  }
}

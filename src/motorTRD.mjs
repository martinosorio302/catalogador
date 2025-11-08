import { normaliza, tokensIncluidos } from './utilsTexto.mjs';

export const TRD_TABLA = [
  { codigo: 'CODI/01', serie: 'Actas de Sesiones', valor: 'Permanente', ag: 2, ap: 0, oaa: 28, total: 30, unidad: 'Consejo Directivo', descripcion: 'Actas y acuerdos de sesiones del Consejo Directivo.' },
  { codigo: 'CODI/02', serie: 'Correspondencia', valor: 'Temporal', ag: 2, ap: 0, oaa: 6, total: 8, unidad: 'Consejo Directivo', descripcion: 'Cartas, oficios y comunicaciones oficiales del Consejo Directivo.' },
  { codigo: 'PREJ/01', serie: 'Resoluciones', valor: 'Permanente', ag: 2, ap: 0, oaa: 28, total: 30, unidad: 'Presidencia Ejecutiva', descripcion: 'Resoluciones jefaturales emitidas por Presidencia Ejecutiva.' },
  { codigo: 'COIN/02', serie: 'Acciones de Control', valor: 'Temporal', ag: 2, ap: 8, oaa: 5, total: 15, unidad: 'Órgano de Control Institucional', descripcion: 'Auditorías, informes y acciones de control posterior.' },
  { codigo: 'COCE/01', serie: 'Expedientes de Quejas y Denuncias', valor: 'Temporal', ag: 2, ap: 8, oaa: 5, total: 15, unidad: 'Control Centralizado', descripcion: 'Expedientes administrativos de quejas y denuncias de usuarios.' },
  { codigo: 'COCE/03', serie: 'Papeles de Trabajo', valor: 'Temporal', ag: 2, ap: 8, oaa: 5, total: 15, unidad: 'Control Centralizado', descripcion: 'Papeles y matrices de auditoría y control interno.' }
];

export function aplicarReglasTRD(avances) {
  return avances.map(d => {
    const serieEncontrada = TRD_TABLA.find(s => normaliza(d.serie).includes(normaliza(s.serie)));
    if (!serieEncontrada) return { ...d, temporalidad: 'Temporal', destinoFinal: 'Eliminación', plazoConservacionAnios: 5 };

    const temporalidad = serieEncontrada.valor === 'Permanente' ? 'Permanente' : 'Temporal';
    let destino = 'Eliminación';
    if (temporalidad === 'Permanente') destino = 'Conservación Permanente';
    else if (serieEncontrada.oaa >= 5) destino = 'Transferencia al Archivo Central';

    return {
      ...d,
      codigoSerie: serieEncontrada.codigo,
      serie: serieEncontrada.serie,
      productor: serieEncontrada.unidad,
      temporalidad,
      plazoConservacionAnios: serieEncontrada.total,
      destinoFinal: destino,
      observaciones: `${serieEncontrada.codigo} · ${serieEncontrada.descripcion}`
    };
  });
}

export function simularAnalisisPDF(nombrePDF) {
  const base = [
    { id: 'EXP-2025-001', tipoUnidad: 'Expediente', serie: 'Actas de Sesiones', tituloAsunto: 'Actas del Consejo Directivo 2025', productor: 'Consejo Directivo', folios: 122 },
    { id: 'DOC-2025-015', tipoUnidad: 'Documento', serie: 'Resoluciones', tituloAsunto: 'Resolución Jefatural N° 124-2025', productor: 'Presidencia Ejecutiva', folios: 3 },
    { id: 'DOC-2025-016', tipoUnidad: 'Documento', serie: 'Expedientes de Quejas y Denuncias', tituloAsunto: 'Expediente de denuncia administrativa 2025', productor: 'Control Centralizado', folios: 48 }
  ];
  return aplicarReglasTRD(base);
}

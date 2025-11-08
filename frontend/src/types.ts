export type DocumentoBase = {
  id: string
  tipoUnidad: 'Expediente' | 'Documento'
  codigoExpediente?: string
  tituloAsunto: string
  serie: string
  subserie?: string
  tipoDocumental?: string
  productor: string
  fechaDoc: string
  fechaIni?: string
  fechaFin?: string
  folios: number
  soporte: 'Papel' | 'Digital' | 'Mixto'
  confidencial: boolean
  ubicacionFisica?: string
  valorPrimario: string
  valorSecundario: string
  temporalidad: 'Permanente' | 'Temporal'
  plazoConservacionAnios: number
  destinoFinal: string
  validado: boolean
  creadoPor: string
  creadoEl: string
  revisadoPor?: string
  revisadoEl?: string
}

export type OcrResult = { loteNombre: string; unidades: DocumentoBase[] }

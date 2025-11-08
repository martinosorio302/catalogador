export type DocumentoBase = {
  id: string;
  tipoUnidad: string;
  codigoExpediente?: string;
  tituloAsunto?: string;
  serie?: string;
  subserie?: string;
  tipoDocumental?: string;
  productor?: string;
  fechaDoc?: string;
  fechaIni?: string;
  fechaFin?: string;
  folios?: number;
  soporte?: string;
  confidencial?: boolean;
  ubicacionFisica?: string;
  observaciones?: string;
  valorPrimario?: string;
  valorSecundario?: string;
  temporalidad?: 'Permanente' | 'Temporal';
  plazoConservacionAnios?: number;
  destinoFinal?: string;
  validado?: boolean;
  creadoPor?: string;
  creadoEl?: string;
};

export type TokenRule = {
  tokens: string[];
  codes: string[];
};

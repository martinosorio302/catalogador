-- retencion_schema.sql
CREATE TABLE IF NOT EXISTS series_retencion (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fuente_pdf TEXT,
  pagina_aprox INTEGER,
  sector TEXT,
  fondo_documental TEXT,
  unidad_productora TEXT,
  fraccion_documental TEXT,
  codigo_serie TEXT NOT NULL,
  serie_documental TEXT NOT NULL,
  tipo_documento TEXT,
  valor_serie TEXT CHECK (valor_serie IN ('PERMANENTE','TEMPORAL')),
  retencion_ag INTEGER DEFAULT 0,
  retencion_ap INTEGER DEFAULT 0,
  retencion_oaa INTEGER DEFAULT 0,
  retencion_total INTEGER DEFAULT 0,
  valoracion_decision TEXT CHECK (valoracion_decision IN ('TRANSFERENCIA','ELIMINACION')),
  valoracion_destino TEXT,
  valoracion_momento TEXT,
  valoracion_justifica TEXT,
  hash_fila TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS idx_codigo_serie ON series_retencion(codigo_serie);
CREATE INDEX IF NOT EXISTS idx_unidad_prod ON series_retencion(unidad_productora);
CREATE INDEX IF NOT EXISTS idx_valor_serie ON series_retencion(valor_serie);

from pathlib import Path
from engine import trd

def classify_document_text(text: str, asuntoUnidad: str | None = None, titulo: str | None = None, productor: str | None = None):
    payload = {
        'asuntoUnidad': asuntoUnidad,
        'titulo': titulo,
        'productor': productor,
        'serie': None,
    }
    return trd.aplicar_reglas_trd(payload)

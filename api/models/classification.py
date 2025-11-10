from pydantic import BaseModel
from typing import Optional, Dict, Any


class ClassifyRequest(BaseModel):
    asuntoUnidad: Optional[str] = None
    titulo: Optional[str] = None
    productor: Optional[str] = None
    serie: Optional[str] = None


class ClassifyResponse(BaseModel):
    code: Optional[str]
    tituloSerie: Optional[str]
    plazoConservacionAnios: Optional[int]
    temporalidad: Optional[str]
    destino: Optional[str]
    descripcionInventario: Optional[str] = None

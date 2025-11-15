
from pydantic import BaseModel


class ClassifyRequest(BaseModel):
    asuntoUnidad: str | None = None
    titulo: str | None = None
    productor: str | None = None
    serie: str | None = None


class ClassifyResponse(BaseModel):
    code: str | None
    tituloSerie: str | None
    plazoConservacionAnios: int | None
    temporalidad: str | None
    destino: str | None
    descripcionInventario: str | None = None

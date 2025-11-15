
from pydantic import BaseModel


class ClassifyRequest(BaseModel):
    """Request model for document classification.

    Uses camelCase to match EsSalud API specification.
    """
    asuntoUnidad: str | None = None  # noqa: N815
    titulo: str | None = None
    productor: str | None = None
    serie: str | None = None


class ClassifyResponse(BaseModel):
    """Response model for document classification.

    Uses camelCase to match EsSalud API specification.
    """
    code: str | None
    tituloSerie: str | None  # noqa: N815
    plazoConservacionAnios: int | None  # noqa: N815
    temporalidad: str | None
    destino: str | None
    descripcionInventario: str | None = None  # noqa: N815

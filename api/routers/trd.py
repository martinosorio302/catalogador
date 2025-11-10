from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any
from engine import trd

router = APIRouter()


class TRDRequest(BaseModel):
    serie: Optional[str] = None
    subserie: Optional[str] = None
    tipo: Optional[str] = None
    titulo: Optional[str] = None
    productor: Optional[str] = None
    asuntoUnidad: Optional[str] = None


@router.post("/classify")
def classify(req: TRDRequest) -> Dict[str, Any]:
    # use Pydantic v2 model_dump for compatibility
    payload = req.model_dump()
    out = trd.aplicar_reglas_trd(payload)
    code = out.get("code")
    if code:
        out["descripcionInventario"] = trd.INVENTARIO_DESCRIPCION.get(code)
    return out

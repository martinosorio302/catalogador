from fastapi import APIRouter
from ..models.classification import ClassifyRequest, ClassifyResponse
from engine import trd

router = APIRouter()


@router.post("/classify", response_model=ClassifyResponse)
def classify(req: ClassifyRequest):
    # use Pydantic v2 model_dump for compatibility
    payload = req.model_dump()
    out = trd.aplicar_reglas_trd(payload)
    # attach inventory description when available
    code = out.get("code")
    if code:
        out["descripcionInventario"] = trd.INVENTARIO_DESCRIPCION.get(code)
    return out

from fastapi import APIRouter

from engine import trd

from ..models.classification import ClassifyRequest, ClassifyResponse

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


@router.get("/trd-info")
def get_trd_info():
    """Get TRD table information and statistics."""
    codes = {entry.get("code") for entry in trd.TRD_TABLA if entry.get("code")}
    return {
        "total_entries": len(trd.TRD_TABLA),
        "total_codes": len(codes),
        "sample_entries": trd.TRD_TABLA[:5] if len(trd.TRD_TABLA) > 0 else [],
        "index_tokens": len(trd.INDICE_TOKENS),
        "inventory_descriptions": len(trd.INVENTARIO_DESCRIPCION),
    }

from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health():
    """Healthcheck endpoint required to return {status: 'ok'}"""
    return {"ok": True}

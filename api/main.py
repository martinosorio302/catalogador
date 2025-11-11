from fastapi import FastAPI
from .routers import health, classify, files, admin
import logging

app = FastAPI(title="Catalogador – API")

# configure logging
logger = logging.getLogger("catalogador")
if not logger.handlers:
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s"
    )

app.include_router(health.router, prefix="")
app.include_router(classify.router, prefix="")
app.include_router(files.router, prefix="")
app.include_router(admin.router, prefix="")


@app.on_event("startup")
async def startup_event():
    logger.info("Catalogador API starting up")

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from .routers import admin, classify, files, health

# configure logging
logger = logging.getLogger("catalogador")
if not logger.handlers:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Catalogador API starting up")
    yield
    # Shutdown (if needed)
    logger.info("Catalogador API shutting down")


app = FastAPI(title="Catalogador – API", lifespan=lifespan)

app.include_router(health.router, prefix="")
app.include_router(classify.router, prefix="")
app.include_router(files.router, prefix="")
app.include_router(admin.router, prefix="")

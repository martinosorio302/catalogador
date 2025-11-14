from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routers import health, classify, files, admin
import logging

app = FastAPI(title="Catalogador – API")

# Configure CORS to allow frontend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# configure logging
logger = logging.getLogger("catalogador")
if not logger.handlers:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")

app.include_router(health.router, prefix="")
app.include_router(classify.router, prefix="")
app.include_router(files.router, prefix="")
app.include_router(admin.router, prefix="")


@app.on_event("startup")
async def startup_event():
    logger.info("Catalogador API starting up")


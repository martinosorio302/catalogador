import logging
import os
from contextlib import asynccontextmanager
from logging.handlers import RotatingFileHandler
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .routers import admin, classify, files, health

# Configure logging with file rotation
logger = logging.getLogger("catalogador")
if not logger.handlers:
    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(
        logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
    )
    logger.addHandler(console_handler)

    # File handler with rotation (10MB max, 5 backups)
    log_dir = Path(os.getenv("LOG_DIR", "logs"))
    log_dir.mkdir(parents=True, exist_ok=True)
    file_handler = RotatingFileHandler(
        log_dir / "catalogador_api.log",
        maxBytes=10 * 1024 * 1024,  # 10MB
        backupCount=5,
        encoding="utf-8",
    )
    file_handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s"))
    logger.addHandler(file_handler)
    logger.setLevel(logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Catalogador API starting up")
    logger.info("Log directory: %s", Path(os.getenv("LOG_DIR", "logs")).resolve())
    yield
    # Shutdown
    logger.info("Catalogador API shutting down")


app = FastAPI(
    title="Catalogador EsSalud API",
    description="Sistema de clasificación y gestión documental TRD para EsSalud",
    version="2.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS middleware - allow desktop app and web clients
allowed_origins = os.getenv("CORS_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins if "*" not in allowed_origins else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Global exception handler for unexpected errors
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.exception("Unhandled exception in %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "detail": str(exc) if os.getenv("DEBUG") else "An unexpected error occurred",
        },
    )


app.include_router(health.router, prefix="", tags=["Health"])
app.include_router(classify.router, prefix="", tags=["Classification"])
app.include_router(files.router, prefix="", tags=["Files"])
app.include_router(admin.router, prefix="", tags=["Admin"])

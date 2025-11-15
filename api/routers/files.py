import logging
import os
import tempfile
from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile

from engine import trd

try:
    import fitz  # PyMuPDF

    HAS_PYMUPDF = True
except ImportError:
    HAS_PYMUPDF = False

logger = logging.getLogger("catalogador.files")

router = APIRouter()


def extract_text_from_pdf(pdf_path: Path) -> str:
    """Extract text from PDF using PyMuPDF."""
    if not HAS_PYMUPDF:
        return ""

    try:
        doc = fitz.open(str(pdf_path))
        text_parts = []
        for page in doc:
            text_parts.append(page.get_text())
        doc.close()
        return "\n".join(text_parts)
    except (OSError, RuntimeError) as e:
        logger.error("Failed to extract text from PDF %s: %s", pdf_path, e)
        return ""


@router.post("/upload")
async def upload(file: UploadFile = File(...)):
    """Upload PDF file, extract text, and classify using TRD rules.

    Security features:
    - Filename sanitization (path traversal prevention)
    - File size limit (default 20MB, configurable via MAX_UPLOAD_BYTES)
    - Content-Type validation
    - Extension whitelist (.pdf only)
    """
    # Validate file extension
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(
            status_code=400, detail="Only PDF files are allowed. Filename must end with .pdf"
        )

    # Validate Content-Type (note: can be spoofed, but adds defense-in-depth)
    if file.content_type and file.content_type not in [
        "application/pdf",
        "application/octet-stream",
    ]:
        logger.warning("Suspicious Content-Type: %s for file %s", file.content_type, file.filename)

    # Destination directory configurable via UPLOAD_DIR -> DATA_DIR -> repo-local data/uploads
    upload_dir = (
        os.getenv("UPLOAD_DIR")
        or os.getenv("DATA_DIR")
        or (Path(__file__).resolve().parents[1] / "data" / "uploads")
    )
    work = Path(upload_dir)
    work.mkdir(parents=True, exist_ok=True)

    # Sanitize filename to prevent path traversal
    safe_name = Path(file.filename).name
    if not safe_name or safe_name.startswith(".") or ".." in safe_name:
        raise HTTPException(status_code=400, detail="Invalid filename")
    dest = work / safe_name
    # enforce max size if provided
    max_bytes = int(os.getenv("MAX_UPLOAD_BYTES") or 20000000)
    # attempt to read stream but abort if larger than max
    try:
        # read in chunks and write to dest
        total = 0
        with dest.open("wb") as fh:
            while True:
                chunk = await file.read(8192)
                if not chunk:
                    break
                total += len(chunk)
                if total > max_bytes:
                    fh.close()
                    try:
                        dest.unlink(missing_ok=True)
                    except OSError as e:
                        logger.warning("Failed to cleanup oversized file %s: %s", dest, e)
                    raise HTTPException(status_code=413, detail="Uploaded file too large")
                fh.write(chunk)
    except HTTPException:
        raise
    except OSError as e:
        logger.exception("Failed to save upload")
        raise HTTPException(status_code=500, detail=str(e))

    # Extract text from PDF and classify
    classification_result = {"extracted": False}
    if safe_name.lower().endswith(".pdf"):
        try:
            extracted_text = extract_text_from_pdf(dest)
            if extracted_text:
                # Use first 500 chars as titulo for classification
                payload = {
                    "titulo": extracted_text[:500],
                    "asuntoUnidad": extracted_text[:200],
                }
                classification_result = trd.aplicar_reglas_trd(payload)
                classification_result["extracted"] = True
                classification_result["text_length"] = len(extracted_text)

                # Add inventory description if code found
                code = classification_result.get("code")
                if code:
                    classification_result["descripcionInventario"] = trd.INVENTARIO_DESCRIPCION.get(
                        code
                    )
            else:
                classification_result["error"] = "No se pudo extraer texto del PDF"
        except (KeyError, AttributeError, ValueError) as e:
            logger.error("Classification error for %s: %s", safe_name, e)
            classification_result["error"] = str(e)

    return {
        "saved": str(dest),
        "filename": safe_name,
        "size_bytes": total,
        "classification": classification_result,
    }


@router.get("/documents")
def list_documents() -> dict:
    work = Path(tempfile.gettempdir()) / "catalogador_uploads"
    if not work.exists():
        return {"documents": []}
    return {"documents": [str(p) for p in work.iterdir() if p.is_file()]}

from fastapi import APIRouter, UploadFile, File, HTTPException
from pathlib import Path
import tempfile
import os
import logging

logger = logging.getLogger("catalogador.files")

router = APIRouter()


@router.post('/upload')
async def upload(file: UploadFile = File(...)):
    """Save an uploaded file to a temporary workspace and return its path."""
    # Destination directory configurable via UPLOAD_DIR -> DATA_DIR -> repo-local data/uploads
    upload_dir = os.getenv('UPLOAD_DIR') or os.getenv('DATA_DIR') or (Path(__file__).resolve().parents[1] / 'data' / 'uploads')
    work = Path(upload_dir)
    work.mkdir(parents=True, exist_ok=True)
    # sanitize filename to prevent path traversal
    safe_name = Path(file.filename).name
    dest = work / safe_name
    # enforce max size if provided
    max_bytes = int(os.getenv('MAX_UPLOAD_BYTES') or 20000000)
    # attempt to read stream but abort if larger than max
    try:
        # read in chunks and write to dest
        total = 0
        with dest.open('wb') as fh:
            while True:
                chunk = await file.read(8192)
                if not chunk:
                    break
                total += len(chunk)
                if total > max_bytes:
                    fh.close()
                    try:
                        dest.unlink(missing_ok=True)
                    except Exception:
                        pass
                    raise HTTPException(status_code=413, detail='Uploaded file too large')
                fh.write(chunk)
    except HTTPException:
        raise
    except Exception as e:
        logger.exception('Failed to save upload')
        raise HTTPException(status_code=500, detail=str(e))
    return {"saved": str(dest)}


@router.get('/documents')
def list_documents():
    work = Path(tempfile.gettempdir()) / 'catalogador_uploads'
    if not work.exists():
        return {"documents": []}
    return {"documents": [str(p) for p in work.iterdir() if p.is_file()]}

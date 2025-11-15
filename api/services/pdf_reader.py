import logging
from pathlib import Path

logger = logging.getLogger(__name__)


def read_pdf_text(path: Path) -> str:
    """Extract text from PDF file using PyMuPDF.

    Args:
        path: Path to PDF file

    Returns:
        Extracted text as string, empty string if extraction fails
    """
    try:
        # Lazy import to keep runtime light unless used
        import fitz

        doc = fitz.open(str(path))
        text = "\n".join(page.get_text() or "" for page in doc)
        doc.close()
        return text
    except ImportError:
        logger.error("PyMuPDF (fitz) not installed, cannot extract PDF text")
        return ""
    except (OSError, RuntimeError) as e:
        logger.error("Failed to read PDF %s: %s", path, e)
        return ""

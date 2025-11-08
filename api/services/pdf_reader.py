from pathlib import Path

def read_pdf_text(path: Path) -> str:
    try:
        # Lazy import to keep runtime light unless used
        import fitz
        doc = fitz.open(str(path))
        return "\n".join(page.get_text() or "" for page in doc)
    except Exception:
        # Last-resort: return empty string
        return ""

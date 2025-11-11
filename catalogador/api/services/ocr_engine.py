from pathlib import Path
import subprocess
import shutil


def extract_text_from_pdf(path: Path) -> str:
    """Attempt to extract text from PDF.

    Prefer PyMuPDF (fitz) if available, else try pdftotext, else return empty string.
    """
    try:
        import fitz

        doc = fitz.open(str(path))
        text_parts = []
        for page in doc:
            text = page.get_text()
            if text:
                text_parts.append(text)
        return "\n".join(text_parts)
    except Exception:
        pass

    # Try pdftotext (poppler)
    if shutil.which("pdftotext"):
        out = subprocess.run(
            ["pdftotext", "-layout", "-enc", "UTF-8", str(path), "-"],
            stdout=subprocess.PIPE,
        )
        return out.stdout.decode("utf-8", errors="replace")

    # Fallback: empty
    return ""

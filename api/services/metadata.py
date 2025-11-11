from pathlib import Path
from typing import Dict


def extract_metadata(path: Path) -> Dict[str, str]:
    # Minimal metadata extractor; can be extended later
    return {
        "filename": path.name,
        "size": str(path.stat().st_size) if path.exists() else "0",
    }

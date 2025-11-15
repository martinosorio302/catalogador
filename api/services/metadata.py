from pathlib import Path


def extract_metadata(path: Path) -> dict[str, str]:
    # Minimal metadata extractor; can be extended later
    return {
        "filename": path.name,
        "size": str(path.stat().st_size) if path.exists() else "0",
    }

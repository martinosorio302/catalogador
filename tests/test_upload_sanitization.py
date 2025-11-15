import importlib
import sys

from fastapi.testclient import TestClient

sys.path.insert(
    0,
    str(importlib.util.find_spec("api").loader.path if importlib.util.find_spec("api") else "."),
)
from pathlib import Path

from api.main import app


def test_upload_sanitizes_and_limits(tmp_path, monkeypatch):
    client = TestClient(app)
    # set UPLOAD_DIR to tmp_path
    monkeypatch.setenv("UPLOAD_DIR", str(tmp_path))

    # Test 1: Non-PDF file should be rejected with 400
    big = b"a" * (1024 * 1024 + 1)
    files = {"file": ("..\\evil.txt", big, "text/plain")}
    r = client.post("/upload", files=files)
    assert r.status_code == 400  # Rejected due to extension, not size
    assert "PDF" in r.json().get("detail", "")

    # Test 2: Large PDF file exceeds limit -> 413
    monkeypatch.setenv("MAX_UPLOAD_BYTES", "1024")
    files = {"file": ("large.pdf", big, "application/pdf")}
    r = client.post("/upload", files=files)
    assert r.status_code == 413

    # Test 3: Small PDF file within limit -> 200
    small_pdf = b"%PDF-1.4\n%EOF"  # Minimal valid PDF
    files = {"file": ("safe.pdf", small_pdf, "application/pdf")}
    r = client.post("/upload", files=files)
    assert r.status_code == 200
    saved = r.json().get("saved")
    assert saved is not None
    assert Path(saved).name == "safe.pdf"

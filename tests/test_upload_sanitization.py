import sys
import importlib
from fastapi.testclient import TestClient

sys.path.insert(
    0,
    str(importlib.util.find_spec("api").loader.path if importlib.util.find_spec("api") else "."),
)
from api.main import app
from pathlib import Path


def test_upload_sanitizes_and_limits(tmp_path, monkeypatch):
    client = TestClient(app)
    # set UPLOAD_DIR to tmp_path
    monkeypatch.setenv("UPLOAD_DIR", str(tmp_path))
    # create a fake large file content
    big = b"a" * (1024 * 1024 + 1)
    files = {"file": ("..\\evil.txt", big, "text/plain")}
    # set small max
    monkeypatch.setenv("MAX_UPLOAD_BYTES", "1024")
    r = client.post("/upload", files=files)
    assert r.status_code == 413
    # now smaller file
    small = b"hello"
    files = {"file": ("safe.txt", small, "text/plain")}
    r = client.post("/upload", files=files)
    assert r.status_code == 200
    saved = r.json().get("saved")
    assert saved is not None
    assert Path(saved).name == "safe.txt"

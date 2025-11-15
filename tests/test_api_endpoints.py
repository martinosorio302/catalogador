import importlib
import sys

from fastapi.testclient import TestClient

# ensure repo root is on path
sys.path.insert(
    0,
    str(importlib.util.find_spec("api").loader.path if importlib.util.find_spec("api") else "."),
)
from api.main import app


def test_health():
    client = TestClient(app)
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json().get("ok") is True


def test_classify_basic():
    client = TestClient(app)
    payload = {
        "asuntoUnidad": "CONSEJO DIRECTIVO",
        "titulo": "Actas de sesiones",
        "productor": "Unidad X",
    }
    r = client.post("/classify", json=payload)
    assert r.status_code == 200
    data = r.json()
    # should return a code or fallback structure
    assert "code" in data

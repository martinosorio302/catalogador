import importlib
import sys
from fastapi.testclient import TestClient

sys.path.insert(
    0,
    str(importlib.util.find_spec("api").loader.path if importlib.util.find_spec("api") else "."),
)
from api.main import app


def test_reload_requires_token(monkeypatch):
    client = TestClient(app)
    # set token
    monkeypatch.setenv("ADMIN_RELOAD_TOKEN", "tok123")
    # without header -> 403
    r = client.post("/reload")
    assert r.status_code == 403
    # with wrong header
    r = client.post("/reload", headers={"X-Admin-Token": "wrong"})
    assert r.status_code == 403
    # with correct header
    r = client.post("/reload", headers={"X-Admin-Token": "tok123"})
    assert r.status_code == 200
    assert r.json().get("ok") is True

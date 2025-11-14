import json
import subprocess
import sys
import time
from pathlib import Path

import requests


def wait_for_health(url, timeout=10.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            r = requests.get(url, timeout=1)
            if r.status_code == 200:
                return True
        except Exception:
            pass
        time.sleep(0.2)
    return False


def test_import_retencion_integration(tmp_path):
    # Start uvicorn on a free port to avoid collisions
    import socket

    def _find_free_port():
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.bind(("127.0.0.1", 0))
        addr, port = s.getsockname()
        s.close()
        return port

    port = _find_free_port()
    url = f"http://127.0.0.1:{port}"

    uvicorn_proc = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "uvicorn",
            "api.main:app",
            "--host",
            "127.0.0.1",
            "--port",
            str(port),
            "--log-level",
            "warning",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    try:
        assert wait_for_health(url + "/health", timeout=15), "uvicorn did not become healthy"

        # create a small source JSON file that import_retencion can read
        src = tmp_path / "src.json"
        rows = [
            {
                "fondo": "A",
                "codigo": "X/01",
                "titulo": "T1",
                "valor": "TEMPORAL",
                "retencion_gestion": 1,
            }
        ]
        src.write_text(json.dumps(rows, ensure_ascii=False), encoding="utf-8")

        # call the import_retencion script as a module so it performs write + reload
        args = [
            sys.executable,
            "-m",
            "tools.import_retencion",
            "--src",
            str(src),
            "--dest",
            "api/data/test_import_integration.json",
            "--reload-host",
            "127.0.0.1",
            "--reload-port",
            str(port),
        ]
        subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        # Ensure the dest file was written inside api/data
        dest = Path("api/data/test_import_integration.json")
        assert dest.exists(), f"Destination file {dest} not created"

        data = json.loads(dest.read_text(encoding="utf-8"))
        assert isinstance(data, list) and len(data) == 1
        assert data[0]["codigo"] == "X/01"

    finally:
        try:
            uvicorn_proc.terminate()
            uvicorn_proc.wait(timeout=5)
        except Exception:
            uvicorn_proc.kill()
        # cleanup any created test artifacts
        try:
            dest = Path("api/data/test_import_integration.json")
            if dest.exists():
                dest.unlink()
        except Exception:
            pass

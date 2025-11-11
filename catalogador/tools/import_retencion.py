#!/usr/bin/env python3
r"""tools/import_retencion.py
--------------------------------
Normalize ingester output into the repository and trigger the running API to
reload. This script is idempotent: it will overwrite destination files and can
optionally call the API reload endpoint.

Behavior added by autofix:
 - Writes normalized JSON to both `api/data/essalud_pcd_anexo02.full.json`
     and repository `data/essalud_pcd_anexo02.full.json` so both dev and
     deployed service locations are covered.
 - POSTs /reload to a configurable host/port (default 127.0.0.1:8000).

Usage:
    python tools/import_retencion.py --src "C:\path\to\retencion_normalizada.json" \
            [--dest "api/data/essalud_pcd_anexo02.full.json"] [--reload]

The script maps common ingester field names into the API's Serie shape
{fondo,codigo,titulo,valor,retencion} and preserves observations if present.
"""

import argparse
import json
from typing import List
from pathlib import Path
import sys
import urllib.request
import os
import tempfile
import time
import errno

try:
    import portalocker
except Exception:
    portalocker = None


FIELD_MAP = {
    "fondo": [
        "fondo",
        "fondo_documental",
        "fondo_documental_norm",
        "fondo_documental_norm",
    ],
    "codigo": [
        "codigo",
        "codigo_serie",
        "serie_codigo",
        "codigo_serie_norm",
        "codigo_serie",
    ],
    "titulo": [
        "titulo",
        "serie_documental",
        "serie",
        "serie_documental_norm",
        "serie_documental",
    ],
    "valor": ["valor", "valor_serie", "valor_serie_norm"],
}


def pick(d, candidates, default=None):
    for k in candidates:
        if k in d and d[k] not in (None, ""):
            #!/usr/bin/env python3
            r"""tools/import_retencion.py
            --------------------------------
            Normalize ingester output into the repository and trigger the running API to
            reload. This script is idempotent: it will overwrite destination files and can
            optionally call the API reload endpoint.

            Behavior added by autofix:
             - Writes normalized JSON to multiple destinations (primary, DATA_DIR, repo data)
             - POSTs /reload to a configurable host/port (default 127.0.0.1:8000).

            Usage:
                python tools/import_retencion.py --src "C:\path\to\retencion_normalizada.json" \
                        [--dest "api/data/essalud_pcd_anexo02.full.json"] [--no-reload]

            The script maps common ingester field names into the API's Serie shape
            {fondo,codigo,titulo,valor,retencion} and preserves observations if present.
            """
            import argparse
            import json
            from typing import List
            from pathlib import Path
            import sys
            import urllib.request
            import os
            import tempfile
            import time
            import errno

            try:
                import portalocker
            except Exception:
                portalocker = None
    obs = pick(
        row,
        ["observaciones", "observacion", "observaciones_norm", "observaciones_raw"],
        None,
    )
    if obs:
        out["observaciones"] = obs
    return out


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


#!/usr/bin/env python3
"""tools/import_retencion.py
--------------------------------
Normalize ingester output into the repository and trigger the running API to
reload. This script is idempotent: it will overwrite destination files and can
optionally call the API reload endpoint.

Behavior added by autofix:
 - Writes normalized JSON to multiple destinations (primary, DATA_DIR, repo data)
 - POSTs /reload to a configurable host/port (default 127.0.0.1:8000).

Usage:
    python -m tools.import_retencion --src "C:\path\to\retencion_normalizada.json" \
            [--dest "api/data/essalud_pcd_anexo02.full.json"] [--no-reload]

The script maps common ingester field names into the API's Serie shape
{fondo,codigo,titulo,valor,retencion} and preserves observations if present.
"""
import argparse
import json
from typing import List
from pathlib import Path
import sys
import urllib.request
import os
import tempfile
import time
import errno

try:
    import portalocker
except Exception:
    portalocker = None


FIELD_MAP = {
    "fondo": [
        "fondo",
        "fondo_documental",
        "fondo_documental_norm",
        "fondo_documental_norm",
    ],
    "codigo": [
        "codigo",
        "codigo_serie",
        "serie_codigo",
        "codigo_serie_norm",
        "codigo_serie",
    ],
    "titulo": [
        "titulo",
        "serie_documental",
        "serie",
        "serie_documental_norm",
        "serie_documental",
    ],
    "valor": ["valor", "valor_serie", "valor_serie_norm"],
}


def pick(d, candidates, default=None):
    for k in candidates:
        if k in d and d[k] not in (None, ""):
            return d[k]
    return default


def map_retention(row):
    r = {}
    keys = {
        "gestion": ["retencion_gestion", "ret_gestion", "gestion"],
        "periferico": ["retencion_periferico", "ret_periferico", "periferico"],
        "central": ["retencion_central", "ret_central", "central"],
        "total": ["retencion_total", "ret_total", "total"],
    }
    for outk, cand in keys.items():
        val = pick(row, cand, 0)
        try:
            r[outk] = int(val)
        except Exception:
            try:
                r[outk] = int(float(val))
            except Exception:
                r[outk] = 0
    return r


def normalize_record(row):
    out = {}
    out["fondo"] = pick(row, FIELD_MAP["fondo"], "")
    out["codigo"] = pick(row, FIELD_MAP["codigo"], "")
    out["titulo"] = pick(row, FIELD_MAP["titulo"], "")
    out["valor"] = pick(row, FIELD_MAP["valor"], "")
    out["retencion"] = map_retention(row)
    obs = pick(
        row,
        ["observaciones", "observacion", "observaciones_norm", "observaciones_raw"],
        None,
    )
    if obs:
        out["observaciones"] = obs
    return out


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def write_dest(records, dest: Path):
    """Atomically write JSON `records` to `dest` (single destination helper)."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(
        prefix=dest.name + ".", suffix=".tmp", dir=str(dest.parent)
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tf:
            json.dump(records, tf, ensure_ascii=False, indent=2)
            tf.flush()
            try:
                os.fsync(tf.fileno())
            except Exception:
                pass
        # Replace with retry to handle transient Windows permission errors when
        # other processes may have the target file briefly open. If portalocker
        # is available we also try to acquire a short exclusive lock on a
        # sidecar lock file to coordinate replaces across processes.
        _attempts = 0
        while True:
            try:
                if portalocker:
                    lock_path = dest.with_name(dest.name + ".lock")
                    with portalocker.Lock(str(lock_path), "w", timeout=5):
                        os.replace(tmp_path, str(dest))
                else:
                    os.replace(tmp_path, str(dest))
                break
            except PermissionError:
                _attempts += 1
                if _attempts >= 6:
                    # final attempt: try to remove target then replace
                    try:
                        if os.path.exists(dest):
                            os.remove(dest)
                    except Exception:
                        pass
                    os.replace(tmp_path, str(dest))
                    break
                time.sleep(0.05 * _attempts)
    finally:
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass


def write_multiple_atomic(records, dest_paths: List[Path]):
    """Write the same JSON `records` atomically to multiple destinations.

    Strategy: create temp files next to each destination, write contents, fsync,
    then replace all targets using os.replace. If any write fails, clean up
    temp files and raise an exception. Uses portalocker when available to
    coordinate cross-process writes to the same destination.
    """
    temps = []
    try:
        for dest in dest_paths:
            dest.parent.mkdir(parents=True, exist_ok=True)
            lock_path = dest.with_name(dest.name + ".lock")
            if portalocker:
                with portalocker.Lock(str(lock_path), "w", timeout=10):
                    fd, tmp_path = tempfile.mkstemp(
                        prefix=dest.name + ".", suffix=".tmp", dir=str(dest.parent)
                    )
                    with os.fdopen(fd, "w", encoding="utf-8") as tf:
                        json.dump(records, tf, ensure_ascii=False, indent=2)
                        tf.flush()
                        try:
                            os.fsync(tf.fileno())
                        except Exception:
                            pass
                    temps.append((tmp_path, str(dest)))
            else:
                fd, tmp_path = tempfile.mkstemp(
                    prefix=dest.name + ".", suffix=".tmp", dir=str(dest.parent)
                )
                with os.fdopen(fd, "w", encoding="utf-8") as tf:
                    json.dump(records, tf, ensure_ascii=False, indent=2)
                    tf.flush()
                    try:
                        os.fsync(tf.fileno())
                    except Exception:
                        pass
                temps.append((tmp_path, str(dest)))

        # all temp files written successfully; perform atomic replace.
        # On Windows an os.replace can raise PermissionError if another
        # process has the destination open. We retry with short backoff and
        # (when available) acquire the sidecar lock while replacing.
        for tmp_path, dest_str in temps:
            dest_path = Path(dest_str)
            attempts = 0
            while True:
                try:
                    if portalocker:
                        lock_path = dest_path.with_name(dest_path.name + ".lock")
                        with portalocker.Lock(str(lock_path), "w", timeout=10):
                            os.replace(tmp_path, dest_str)
                    else:
                        os.replace(tmp_path, dest_str)
                    break
                except PermissionError:
                    attempts += 1
                    if attempts >= 8:
                        # last resort: try to remove the destination and replace
                        try:
                            if dest_path.exists():
                                dest_path.unlink()
                        except Exception:
                            pass
                        # final attempt (let exception propagate if it fails)
                        os.replace(tmp_path, dest_str)
                        break
                    time.sleep(0.05 * attempts)
        temps = []
    except Exception:
        # cleanup temps
        for tmp_path, _ in temps:
            try:
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)
            except Exception:
                pass
        raise


def try_reload(host="127.0.0.1", port=8000, timeout=5):
    url = f"http://{host}:{port}/reload"
    try:
        import requests

        try:
            r = requests.post(url, timeout=timeout)
            try:
                body = r.text
            except Exception:
                body = "<non-text body>"
            print("Reload response:", r.status_code, body)
            return 200 <= r.status_code < 300
        except Exception as e:
            print("Could not reload API via requests:", e)
            return False
    except Exception:
        # fallback to urllib
        req = urllib.request.Request(url, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                body = resp.read().decode("utf-8")
                print("Reload response:", body)
                return True
        except Exception as e:
            print("Could not reload API (it may not be running):", e)
            return False


def main():
    p = argparse.ArgumentParser()
    p.add_argument(
        "--src", required=True, help="Source JSON file produced by the ingester"
    )
    p.add_argument(
        "--dest",
        default="api/data/essalud_pcd_anexo02.full.json",
        help="Primary destination path inside repo",
    )
    p.add_argument(
        "--no-reload",
        action="store_true",
        help="Do not POST /reload to the local API after copying",
    )
    p.add_argument(
        "--reload-host", default="127.0.0.1", help="Host for the API reload endpoint"
    )
    p.add_argument(
        "--reload-port",
        default=8000,
        type=int,
        help="Port for the API reload endpoint (default 8000)",
    )
    args = p.parse_args()

    src = Path(args.src)
    if not src.exists():
        print("Source file not found:", src, file=sys.stderr)
        sys.exit(2)

    data = load_json(src)
    # data may be an object with a "rows" key or a plain list
    if isinstance(data, dict) and "rows" in data and isinstance(data["rows"], list):
        raw = data["rows"]
    elif isinstance(data, list):
        raw = data
    else:
        if isinstance(data, dict):
            raw = [v for v in data.values() if isinstance(v, dict)]
        else:
            raw = []

    print(f"Loaded {len(raw)} records from {src}")

    normalized = [normalize_record(r) for r in raw]

    dest = Path(args.dest)
    dests = [dest]
    data_dir_env = os.getenv("DATA_DIR")
    if data_dir_env:
        data_dir_path = Path(data_dir_env) / dest.name
        dests.append(data_dir_path)
    repo_root_data = Path(__file__).resolve().parents[1] / "data" / dest.name
    dests.append(repo_root_data)

    try:
        write_multiple_atomic(normalized, dests)
        print("Wrote destinations:", ", ".join(str(d) for d in dests))
    except Exception as e:
        print("Failed to write destination files atomically:", e, file=sys.stderr)
        sys.exit(3)

    if not args.no_reload:
        ok = try_reload(host=args.reload_host, port=args.reload_port)
        if not ok:
            print(
                f"Reload to {args.reload_host}:{args.reload_port} failed; you can retry manually."
            )


if __name__ == "__main__":
    main()

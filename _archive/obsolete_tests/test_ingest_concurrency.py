import json
from multiprocessing import Process
from pathlib import Path


def _worker_write(dest_path: str, payload: dict, delay: float = 0.0):
    # Import inside worker to avoid pickle issues
    from tools.import_retencion import write_dest
    import time

    if delay:
        time.sleep(delay)
    write_dest(payload, Path(dest_path))


def test_concurrent_writes(tmp_path):
    dest = tmp_path / "concurrent.json"
    # prepare three different payloads
    payloads = [
        {"id": 1, "value": "A"},
        {"id": 2, "value": "B"},
        {"id": 3, "value": "C"},
    ]

    procs = []
    for i, p in enumerate(payloads):
        pr = Process(target=_worker_write, args=(str(dest), p, i * 0.02))
        pr.start()
        procs.append(pr)

    for pr in procs:
        pr.join(timeout=5)
        if pr.is_alive():
            pr.terminate()

    # dest should exist and contain valid JSON
    assert dest.exists()
    with dest.open("r", encoding="utf-8") as fh:
        final = json.load(fh)
    assert isinstance(final, (list, dict)) or final in payloads

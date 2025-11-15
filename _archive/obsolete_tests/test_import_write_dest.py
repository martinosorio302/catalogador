import json

# import the module under test
from tools import import_retencion as ir


def test_write_dest_atomic(tmp_path):
    records = [
        {
            "fondo": "A",
            "codigo": "X/01",
            "titulo": "Test",
            "valor": "TEMPORAL",
            "retencion": {"gestion": 1, "periferico": 0, "central": 0, "total": 1},
        }
    ]
    dest = tmp_path / "out.json"
    # call write_dest
    ir.write_dest(records, dest)
    assert dest.exists()
    # load and compare
    with dest.open("r", encoding="utf-8") as f:
        data = json.load(f)
    assert data == records

    # call again with different content to ensure replace works
    records2 = [
        {
            "fondo": "B",
            "codigo": "Y/02",
            "titulo": "Test2",
            "valor": "PERMANENTE",
            "retencion": {"gestion": 2, "periferico": 1, "central": 0, "total": 3},
        }
    ]
    ir.write_dest(records2, dest)
    with dest.open("r", encoding="utf-8") as f:
        data2 = json.load(f)
    assert data2 == records2

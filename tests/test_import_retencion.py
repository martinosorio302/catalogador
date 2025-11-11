import json

from catalogador.tools.import_retencion import normalize_record


def test_normalize_record_basic():
    row = {
        "fondo": "FondoX",
        "codigo": "C123",
        "titulo": "Titulo prueba",
        "valor": "ValorY",
        "retencion_gestion": "5",
        "observaciones": "Nota de prueba",
    }

    out = normalize_record(row)

    assert out["fondo"] == "FondoX"
    assert out["codigo"] == "C123"
    assert out["titulo"] == "Titulo prueba"
    assert out["valor"] == "ValorY"
    # retencion fields should be integers and present
    assert isinstance(out["retencion"].get("gestion"), int)
    assert out["retencion"]["gestion"] == 5
    # observations preserved
    assert out.get("observaciones") == "Nota de prueba"

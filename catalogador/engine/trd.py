"""TRD/PCD logic (Python port)"""

from typing import Optional, Dict, Any, List
import unicodedata
import json
from pathlib import Path

# Try to load TRD data from engine/data/trd.json if present. Keep a small
# fallback embedded table in case the JSON is missing (backward compatible).
_DATA_FILE = Path(__file__).resolve().parent / "data" / "trd.json"
_LOADED = {}
if _DATA_FILE.exists():
    try:
        with _DATA_FILE.open("r", encoding="utf-8") as fh:
            _LOADED = json.load(fh)
    except Exception:
        _LOADED = {}


def reload_trd_data() -> dict:
    """Reload TRD data from the JSON file and update module-level structures.

    Returns a small summary dict with counts and errors (if any).
    """
    global _LOADED, TRD_TABLA, INVENTARIO_DESCRIPCION, INDICE_TOKENS
    summary = {"loaded": False, "errors": None, "counts": {}}
    try:
        if _DATA_FILE.exists():
            with _DATA_FILE.open("r", encoding="utf-8") as fh:
                _LOADED = json.load(fh)
        else:
            _LOADED = {}

        TRD_TABLA = _get_list("TRD_TABLA", FALLBACK_TRD_TABLA)
        INVENTARIO_DESCRIPCION = _get_dict("INVENTARIO_DESCRIPCION", {})
        INDICE_TOKENS = _get_list("INDICE_TOKENS", [])

        # Basic schema validation for TRD_TABLA entries
        errors = []
        if isinstance(TRD_TABLA, list):
            for i, entry in enumerate(TRD_TABLA):
                if not isinstance(entry, dict):
                    errors.append(f"entry[{i}] is not an object")
                    continue
                if "code" not in entry or not isinstance(entry.get("code"), str):
                    errors.append(f"entry[{i}].code missing or not str")
                if "titulo" not in entry or not isinstance(entry.get("titulo"), str):
                    errors.append(f"entry[{i}].titulo missing or not str")
                if "valor" not in entry or not isinstance(entry.get("valor"), str):
                    errors.append(f"entry[{i}].valor missing or not str")

        summary["loaded"] = True if not errors else False
        summary["counts"] = {
            "trd_tabla": len(TRD_TABLA) if isinstance(TRD_TABLA, list) else 0,
            "indice_tokens": len(INDICE_TOKENS)
            if isinstance(INDICE_TOKENS, list)
            else 0,
            "inventario_descripcion": len(INVENTARIO_DESCRIPCION)
            if isinstance(INVENTARIO_DESCRIPCION, dict)
            else 0,
        }
        if errors:
            summary["errors"] = "; ".join(errors)
    except Exception as e:
        summary["errors"] = str(e)
    return summary


def _get_list(name: str, default: List[Dict[str, Any]]):
    v = _LOADED.get(name)
    return v if isinstance(v, list) else default


def _get_dict(name: str, default: Dict[str, Any]):
    v = _LOADED.get(name)
    return v if isinstance(v, dict) else default


# Fallbacks (small, safe defaults)
FALLBACK_TRD_TABLA: List[Dict[str, Any]] = [
    {
        "code": "CODI/01",
        "titulo": "ACTAS DE SESIONES",
        "valor": "Permanente",
        "ag": 2,
        "ap": 0,
        "oaa": 28,
        "total": 30,
        "asunto": "CONSEJO DIRECTIVO",
    },
    {
        "code": "CODI/02",
        "titulo": "CORRESPONDENCIA",
        "valor": "Temporal",
        "ag": 2,
        "ap": 0,
        "oaa": 6,
        "total": 8,
        "asunto": "CONSEJO DIRECTIVO",
    },
]

TRD_TABLA = _get_list("TRD_TABLA", FALLBACK_TRD_TABLA)
INVENTARIO_DESCRIPCION = _get_dict("INVENTARIO_DESCRIPCION", {})
INDICE_TOKENS = _get_list("INDICE_TOKENS", [])


def normaliza(s: Optional[str]) -> str:
    if not s:
        return ""
    n = unicodedata.normalize("NFD", s)
    n = "".join(ch for ch in n if unicodedata.category(ch) != "Mn")
    return n.upper()


def texto_indice(
    asunto_unidad: Optional[str], titulo_doc: Optional[str], productor: Optional[str]
) -> str:
    parts = [p for p in (asunto_unidad, titulo_doc, productor) if p]
    return " | ".join(normaliza(p) for p in parts)


def tokens_incluidos(texto: str, tokens: List[str]) -> bool:
    return all(normaliza(t) in texto for t in tokens)


def clasificar_por_tokens(
    asunto_unidad: Optional[str], titulo_doc: Optional[str], productor: Optional[str]
) -> Optional[str]:
    txt = texto_indice(asunto_unidad, titulo_doc, productor)
    for r in INDICE_TOKENS:
        if tokens_incluidos(txt, r.get("tokens", [])):
            codes = r.get("codes") or []
            return codes[0] if codes else None
    return None


def buscar_trd_por_codigo(code: str) -> Optional[Dict[str, Any]]:
    if not code:
        return None
    for x in TRD_TABLA:
        if x.get("code") == code:
            return x
    return None


def buscar_trd_por_asunto_titulo(
    asunto: str, serie_sugerida: Optional[str] = None
) -> Optional[Dict[str, Any]]:
    a = normaliza(asunto or "")
    s = normaliza(serie_sugerida or "")
    for x in TRD_TABLA:
        if normaliza(x.get("asunto", "")) in a and normaliza(x.get("titulo", "")) in s:
            return x
    return None


def aplicar_reglas_trd(input_obj: Dict[str, Optional[str]]) -> Dict[str, Any]:
    por_asunto = None
    if input_obj.get("serie") and input_obj.get("asuntoUnidad"):
        por_asunto = buscar_trd_por_asunto_titulo(
            input_obj.get("asuntoUnidad", ""), input_obj.get("serie", "")
        )
    code_tok = clasificar_por_tokens(
        input_obj.get("asuntoUnidad"),
        input_obj.get("titulo"),
        input_obj.get("productor"),
    )
    entry = por_asunto or (buscar_trd_por_codigo(code_tok) if code_tok else None)

    if entry:
        temporalidad = (
            "Permanente" if entry.get("valor") == "Permanente" else "Temporal"
        )
        destino = (
            "Conservación Permanente" if temporalidad == "Permanente" else "Eliminación"
        )
        if temporalidad == "Temporal" and entry.get("oaa", 0) >= 5:
            destino = "Transferencia al Archivo Central"
        return {
            "code": entry.get("code"),
            "tituloSerie": entry.get("titulo"),
            "plazoConservacionAnios": entry.get("total"),
            "temporalidad": temporalidad,
            "destino": destino,
        }

    return {
        "code": None,
        "tituloSerie": input_obj.get("serie") or "Correspondencia",
        "plazoConservacionAnios": 8,
        "temporalidad": "Temporal",
        "destino": "Eliminación",
    }


if __name__ == "__main__":
    samples = [
        {
            "asuntoUnidad": "CONSEJO DIRECTIVO",
            "titulo": "Actas de sesiones",
            "serie": "Actas",
        },
        {
            "asuntoUnidad": "PRESIDENCIA EJECUTIVA",
            "titulo": "Correspondencia general",
            "serie": "Correspondencia",
        },
    ]
    for s in samples:
        print("Input:", s)
        print("Result:", aplicar_reglas_trd(s))

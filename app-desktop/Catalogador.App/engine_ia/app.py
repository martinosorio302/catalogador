from fastapi import FastAPI, UploadFile, File, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn
import json
import yaml
import os
import hashlib
import re
import fitz
from typing import Dict, Any, List
from schemas.inventory_schema import Inventory
from ml import pipeline_extract, clf_train

app = FastAPI(title="Motor IA Catalogador", version="0.5.0")

app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)

RULES: Dict[str, Any] = {"version": "empty", "mapeos": []}


def file_sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def extract_text_pdf(path: str) -> str:
    out = []
    with fitz.open(path) as doc:
        for page in doc:
            out.append(page.get_text())
    return "\n".join(out)


@app.get("/health")
def health():
    return {"ok": True, "rules_version": str(RULES.get("version", "n/a"))}


@app.post("/rules/load")
async def load_rules(body: str = Body(..., media_type="text/plain")):
    global RULES
    try:
        body_s = body.strip()
        if body_s.startswith("{"):
            RULES = json.loads(body_s)
        else:
            RULES = yaml.safe_load(body_s)
        if not isinstance(RULES, dict):
            RULES = {"version": "invalid", "mapeos": []}
        return {"ok": True, "version": RULES.get("version", "n/a")}
    except Exception as e:
        return JSONResponse(status_code=400, content={"ok": False, "error": str(e)})


@app.post("/analyze")
async def analyze(file: UploadFile = File(...)):
    tmp_path = os.path.join(os.getcwd(), file.filename)
    with open(tmp_path, "wb") as f:
        f.write(await file.read())

    pages = 0
    text = ""
    try:
        with fitz.open(tmp_path) as doc:
            pages = len(doc)
        text = extract_text_pdf(tmp_path)
    except Exception:
        pages = 1
        text = file.filename

    sha = file_sha256(tmp_path)
    try:
        os.remove(tmp_path)
    except Exception:
        pass

    info = pipeline_extract(text=text, pages=pages, rules=RULES)

    titulo = None
    m = re.search(r"(?i)(historia clinica[^\\n]{0,80})", text)
    if m:
        titulo = m.group(1)
    if not titulo:
        titulo = os.path.basename(file.filename)

    payload = {
        "version": "1.0",
        "institucion": "EsSalud",
        "registro": {
            "fondo_documental": "EsSalud - RAAM",
            "seccion": "Por determinar",
            "serie_documental": info.get("serie_documental", "Por determinar"),
            "subserie_documental": info.get("subserie_documental"),
            "fraccion_documental": None,
            "expediente": bool(info.get("expediente", False)),
            "titulo_documental": titulo,
            "asunto": "Detectado automaticamente (revisar)",
            "fechas_extremas": {
                "inicio": info.get("fechas_extremas", {}).get("inicio"),
                "fin": info.get("fechas_extremas", {}).get("fin"),
            },
            "cantidad_folios": int(pages),
            "soporte": "papel",
            "ubicacion_topografica": None,
            "productor": info.get("productor"),
            "valoracion": info.get("valoracion", {}),
            "temporalidad": info.get("temporalidad", {}),
            "disposicion_final": info.get("disposicion_final", "Por definir"),
            "norma_referencia": {
                "pcda": "001-2023-AGN/DDPA",
                "trd_codigo": info.get("norma_trd"),
            },
            "confianza_serie": float(info.get("confianza_serie", 0.4)),
            "observaciones": "Propuesta automatica sujeta a validacion",
        },
        "auditoria": {
            "origen": "ocr+reglas+ia",
            "fecha_procesado": None,
            "hash_documento": "sha256:" + sha,
            "version_reglas": "custom:" + str(RULES.get("version", "n/a")),
        },
    }

    inv = Inventory(**payload)
    return JSONResponse(inv.model_dump())


@app.post("/ml/train")
async def ml_train(samples: List[Dict[str, Any]]):
    # samples esperado: [{ "text":"...", "is_expediente": true/false }, ...]
    try:
        out = clf_train(samples)
        if out.get("ok"):
            return {"ok": True, "trained": out.get("num_samples", 0)}
        return JSONResponse(status_code=400, content=out)
    except Exception as e:
        return JSONResponse(status_code=400, content={"ok": False, "error": str(e)})


@app.post("/report")
async def generate_report(body: Dict[str, Any]):
    # body: { "inventarios":[Inventory...], "filtro":"transferencia|eliminacion|conservacion|todos" }
    inv_list = body.get("inventarios", [])
    flt = (body.get("filtro") or "todos").lower()
    resumen = {"transferencia": 0, "eliminacion": 0, "conservacion": 0, "otros": 0}
    salida: List[Dict[str, Any]] = []

    for inv in inv_list:
        disp = (
            ((inv or {}).get("registro") or {}).get("disposicion_final") or "otros"
        ).lower()
        if "transfer" in disp:
            resumen["transferencia"] += 1
        elif "elimin" in disp:
            resumen["eliminacion"] += 1
        elif "conserv" in disp or "perman" in disp:
            resumen["conservacion"] += 1
        else:
            resumen["otros"] += 1

        if flt == "todos":
            salida.append(inv)
        elif flt.startswith("transfer") and "transfer" in disp:
            salida.append(inv)
        elif flt.startswith("elimin") and "elimin" in disp:
            salida.append(inv)
        elif (flt.startswith("conserv") or flt.startswith("perman")) and (
            "conserv" in disp or "perman" in disp
        ):
            salida.append(inv)

    return {"ok": True, "resumen": resumen, "items": salida}


if __name__ == "__main__":
    uvicorn.run("app:app", host="127.0.0.1", port=8123, reload=True)

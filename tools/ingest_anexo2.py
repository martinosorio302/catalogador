#!/usr/bin/env python3
"""
Ingest ANEXO 2 (PCD EsSalud) -> Normalizacion archivistica
- Convert PDF -> text with layout (pdftotext)
- Parse Series/Fragments/Codes/Retention/Valuation
- Calculate Valuation: ELIMINACION / TRANSFERENCIA
- Export JSON / CSV / SQL seed and a series.seed.json for backend

Usage: python tools/ingest_anexo2.py --pdf <path-to-pdf> [--outdir OUTDIR] [--force]

This is a Python port of the PowerShell ingester to be easier to integrate
with the backend and to avoid PowerShell 5.1 parsing issues.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    import portalocker
except Exception:
    portalocker = None

import tempfile


def find_pdf(hint: str | None) -> Path:
    if hint:
        p = Path(hint)
        if p.exists():
            return p.resolve()
        raise FileNotFoundError(f"PDF not found at {hint}")

    candidates = [
        Path.home() / "Desktop" / "ESSALUD-PCD-ANEXO-2-TABLA.pdf",
        Path.home() / "Downloads" / "ESSALUD-PCD-ANEXO-2-TABLA.pdf",
        Path.home() / "Desktop" / "ESSALUD" / "ESSALUD-PCD-ANEXO-2-TABLA.pdf",
    ]
    for c in candidates:
        if c.exists():
            return c.resolve()
    raise FileNotFoundError(
        "No PDF found. Provide --pdf or place ESSALUD-PCD-ANEXO-2-TABLA.pdf on Desktop/Downloads."
    )


def check_pdftotext() -> bool:
    return shutil.which("pdftotext") is not None


def run_pdftotext(pdf: Path, out_txt: Path) -> None:
    # Prefer pdftotext (Poppler) if available for best layout preservation
    if shutil.which("pdftotext"):
        cmd = [
            "pdftotext",
            "-layout",
            "-enc",
            "UTF-8",
            "-nopgbrk",
            str(pdf),
            str(out_txt),
        ]
        proc = subprocess.run(cmd, capture_output=True)
        if proc.returncode != 0:
            raise RuntimeError(
                f"pdftotext failed: {proc.returncode} {proc.stderr.decode('utf-8', errors='replace')}"
            )
        return

    # Fallback: use a pure-Python extraction (pdfplumber) if pdftotext is missing
    try:
        import pdfplumber
    except Exception:
        # Do not attempt to pip-install at runtime in production; instruct user
        raise RuntimeError(
            "pdftotext not found in PATH and pdfplumber is not installed. "
            "Install Poppler (pdftotext) in PATH or run: python -m pip install pdfplumber"
        )

    # Use pdfplumber to extract text per page (best-effort layout)
    with (
        pdfplumber.open(str(pdf)) as pdff,
        out_txt.open("w", encoding="utf-8") as outfh,
    ):
        for page in pdff.pages:
            text = page.extract_text(x_tolerance=2, y_tolerance=2)
            if text:
                outfh.write(text)
            outfh.write("\n")


def resolve_valorizacion(valor_serie: str, ag: int, ap: int, oaa: int) -> dict[str, Any]:
    total = ag + ap + oaa
    if valor_serie.upper() == "PERMANENTE":
        return {
            "decision": "TRANSFERENCIA",
            "justificacion": "Conservacion permanente segun PCD",
            "destino": "Archivo Central",
            "momento": "Conservar en Archivo Central de forma indefinida.",
        }
    else:
        destino = (
            "Archivo Central (opcional/intermedio)"
            if total >= 10
            else "Archivo de Gestion/Periferico"
        )
        return {
            "decision": "ELIMINACION",
            "justificacion": "Agotado el valor primario y vencidos plazos reglados en AG/AP/OAA.",
            "destino": destino,
            "momento": "Ejecutar eliminacion documental conforme PCD/AGN.",
        }


RX_SECTOR = re.compile(r"^\s*1\.\s*Sector:\s*(.+?)\s*$", re.IGNORECASE)
RX_ENTIDAD = re.compile(r"^\s*2\.\s*Nombre\s+de\s+la\s+entidad:\s*(.+?)\s*$", re.IGNORECASE)
RX_ASUNTO = re.compile(
    r"^\s*3\.\s*Asunto\s+Principal\s+de\s+la\s+Serie\s+Documental:\s*(.+?)\s*$",
    re.IGNORECASE,
)
RX_ENCABEZADO = re.compile(r"4\.|Codigo.*Titulo.*Valor|Periodo", re.IGNORECASE)
# Row: Nº Ord | Código | Título | Valor | AG | AP | OAA | Total
RX_FILA = re.compile(
    r"^\s*(\d+)\s+([A-Z0-9\/\-]+)\s+(.+?)\s+(PERMANENTE|TEMPORAL)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$",
    re.IGNORECASE,
)


def parse_layout_text(txt_path: Path) -> list[dict[str, Any]]:
    parsed: list[dict[str, Any]] = []
    state = {
        "sector": "MINISTERIO DE TRABAJO Y PROMOCION DEL EMPLEO",
        "entidad": "SEGURO SOCIAL DE SALUD (EsSalud)",
        "asunto": None,
        "pagina": 0,
    }

    with txt_path.open("r", encoding="utf-8", errors="replace") as fh:
        lines = [line.rstrip("\n") for line in fh]

    within_table = False
    for _i, line in enumerate(lines, start=1):
        trim = line.strip()
        if re.match(r"^\s*\d+\s+de\s+\d+\s*$", trim):
            state["pagina"] += 1
            continue

        m = RX_SECTOR.match(trim)
        if m:
            state["sector"] = re.sub(r"\s{2,}", " ", m.group(1)).strip()
            continue
        m = RX_ENTIDAD.match(trim)
        if m:
            state["entidad"] = re.sub(r"\s{2,}", " ", m.group(1)).strip()
            continue
        m = RX_ASUNTO.match(trim)
        if m:
            state["asunto"] = re.sub(r"\s{2,}", " ", m.group(1)).strip()
            continue

        if RX_ENCABEZADO.search(trim):
            within_table = True
            continue

        if within_table:
            m = RX_FILA.match(trim)
            if m:
                # ordinal number in table (not used in output)
                # _nord = int(m.group(1))
                codigo = m.group(2).strip()
                titulo = re.sub(r"\s{2,}", " ", m.group(3)).strip()
                valor = m.group(4).upper().strip()
                ag = int(m.group(5))
                ap = int(m.group(6))
                oaa = int(m.group(7))
                total = int(m.group(8))

                fraccion = None
                if "/" in codigo:
                    fraccion = codigo.split("/")[0]

                unidad = state["asunto"] if state["asunto"] else state["entidad"]
                val = resolve_valorizacion(valor, ag, ap, oaa)

                obj = {
                    "fuente_pdf": txt_path.name,
                    "pagina_aprox": state["pagina"],
                    "sector": state["sector"],
                    "fondo_documental": state["entidad"],
                    "unidad_productora": unidad,
                    "fraccion_documental": fraccion,
                    "codigo_serie": codigo,
                    "serie_documental": titulo,
                    "tipo_documento": titulo,
                    "valor_serie": valor,
                    "retencion_ag": ag,
                    "retencion_ap": ap,
                    "retencion_oaa": oaa,
                    "retencion_total": total,
                    "valoracion_decision": val["decision"],
                    "valoracion_destino": val["destino"],
                    "valoracion_momento": val["momento"],
                    "valoracion_justifica": val["justificacion"],
                    "hash_fila": "",
                }

                # compute hash
                js = json.dumps(obj, ensure_ascii=False, sort_keys=True).encode("utf-8")
                obj["hash_fila"] = hashlib.sha256(js).hexdigest()

                parsed.append(obj)
                continue

            # detect end of table heuristically
            if re.search(
                r"^TABLA\s+GENERAL\s+DE\s+RETENCION\s+DE\s+DOCUMENTOS",
                trim,
                re.IGNORECASE,
            ):
                within_table = False
                continue

    return parsed


def export_artifacts(parsed: list[dict[str, Any]], pdf_path: Path, outdir: Path) -> None:
    data_dir = outdir / "data"
    data_dir.mkdir(parents=True, exist_ok=True)

    def safe_write_json(dest: Path, obj: object) -> None:
        tmp_path = None
        lock_path = dest.with_name(dest.name + ".lock")
        if portalocker:
            try:
                with portalocker.Lock(str(lock_path), "w", timeout=10):
                    fd, tmp_path = tempfile.mkstemp(
                        prefix=dest.name + ".", suffix=".tmp", dir=str(dest.parent)
                    )
                    with os.fdopen(fd, "w", encoding="utf-8") as tf:
                        json.dump(obj, tf, ensure_ascii=False, indent=2)
                        tf.flush()
                        try:
                            os.fsync(tf.fileno())
                        except Exception:
                            pass
                    os.replace(tmp_path, str(dest))
                    tmp_path = None
            finally:
                if tmp_path and os.path.exists(tmp_path):
                    try:
                        os.remove(tmp_path)
                    except Exception:
                        pass
        else:
            fd, tmp_path = tempfile.mkstemp(
                prefix=dest.name + ".", suffix=".tmp", dir=str(dest.parent)
            )
            try:
                with os.fdopen(fd, "w", encoding="utf-8") as tf:
                    json.dump(obj, tf, ensure_ascii=False, indent=2)
                    tf.flush()
                    try:
                        os.fsync(tf.fileno())
                    except Exception:
                        pass
                os.replace(tmp_path, str(dest))
                tmp_path = None
            finally:
                if tmp_path and os.path.exists(tmp_path):
                    try:
                        os.remove(tmp_path)
                    except Exception:
                        pass

    json_path = data_dir / "retencion_normalizada.json"
    safe_write_json(json_path, parsed)

    csv_path = data_dir / "retencion_normalizada.csv"
    if parsed:
        keys = [
            "fuente_pdf",
            "pagina_aprox",
            "sector",
            "fondo_documental",
            "unidad_productora",
            "fraccion_documental",
            "codigo_serie",
            "serie_documental",
            "tipo_documento",
            "valor_serie",
            "retencion_ag",
            "retencion_ap",
            "retencion_oaa",
            "retencion_total",
            "valoracion_decision",
            "valoracion_destino",
            "valoracion_momento",
            "valoracion_justifica",
            "hash_fila",
        ]
        # write CSV to a tempfile then move into place
        fd = None
        tmp_path = None
        try:
            fd, tmp_path = tempfile.mkstemp(
                prefix=csv_path.name + ".", suffix=".tmp", dir=str(csv_path.parent)
            )
            with os.fdopen(fd, "w", encoding="utf-8", newline="") as fh:
                writer = csv.DictWriter(fh, fieldnames=keys)
                writer.writeheader()
                for r in parsed:
                    writer.writerow(r)
                fh.flush()
                try:
                    os.fsync(fh.fileno())
                except Exception:
                    pass
            os.replace(tmp_path, str(csv_path))
            tmp_path = None
        finally:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.remove(tmp_path)
                except Exception:
                    pass

    # SQL schema and seed
    sql_schema = """-- retencion_schema.sql
CREATE TABLE IF NOT EXISTS series_retencion (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fuente_pdf TEXT,
  pagina_aprox INTEGER,
  sector TEXT,
  fondo_documental TEXT,
  unidad_productora TEXT,
  fraccion_documental TEXT,
  codigo_serie TEXT NOT NULL,
  serie_documental TEXT NOT NULL,
  tipo_documento TEXT,
  valor_serie TEXT CHECK (valor_serie IN ('PERMANENTE','TEMPORAL')),
  retencion_ag INTEGER DEFAULT 0,
  retencion_ap INTEGER DEFAULT 0,
  retencion_oaa INTEGER DEFAULT 0,
  retencion_total INTEGER DEFAULT 0,
  valoracion_decision TEXT CHECK (valoracion_decision IN ('TRANSFERENCIA','ELIMINACION')),
  valoracion_destino TEXT,
  valoracion_momento TEXT,
  valoracion_justifica TEXT,
  hash_fila TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS idx_codigo_serie ON series_retencion(codigo_serie);
CREATE INDEX IF NOT EXISTS idx_unidad_prod ON series_retencion(unidad_productora);
CREATE INDEX IF NOT EXISTS idx_valor_serie ON series_retencion(valor_serie);
"""
    schema_path = data_dir / "retencion_schema.sql"
    # atomic write of schema
    fd = None
    tmp_path = None
    try:
        fd, tmp_path = tempfile.mkstemp(
            prefix=schema_path.name + ".", suffix=".tmp", dir=str(schema_path.parent)
        )
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(sql_schema)
            fh.flush()
            try:
                os.fsync(fh.fileno())
            except Exception:
                pass
        os.replace(tmp_path, str(schema_path))
        tmp_path = None
    finally:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass

    seed_path = data_dir / "retencion_seed.sql"
    fd = None
    tmp_path = None
    try:
        fd, tmp_path = tempfile.mkstemp(
            prefix=seed_path.name + ".", suffix=".tmp", dir=str(seed_path.parent)
        )
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write("BEGIN TRANSACTION;\n")
            for r in parsed:
                vals = [
                    r["fuente_pdf"].replace("'", "''"),
                    str(r["pagina_aprox"]),
                    r["sector"].replace("'", "''"),
                    r["fondo_documental"].replace("'", "''"),
                    r["unidad_productora"].replace("'", "''"),
                    (r.get("fraccion_documental") or "").replace("'", "''"),
                    r["codigo_serie"].replace("'", "''"),
                    r["serie_documental"].replace("'", "''"),
                    r["tipo_documento"].replace("'", "''"),
                    r["valor_serie"],
                    str(r["retencion_ag"]),
                    str(r["retencion_ap"]),
                    str(r["retencion_oaa"]),
                    str(r["retencion_total"]),
                    r["valoracion_decision"],
                    r["valoracion_destino"].replace("'", "''"),
                    r["valoracion_momento"].replace("'", "''"),
                    r["valoracion_justifica"].replace("'", "''"),
                    r["hash_fila"],
                ]

                def q(x):
                    try:
                        int(x)
                        return x
                    except Exception:
                        return f"'{x}'"

                vals_sql = ", ".join([q(v) for v in vals])
                fh.write(
                    f"INSERT OR IGNORE INTO series_retencion (fuente_pdf,pagina_aprox,sector,fondo_documental,unidad_productora,fraccion_documental,codigo_serie,serie_documental,tipo_documento,valor_serie,retencion_ag,retencion_ap,retencion_oaa,retencion_total,valoracion_decision,valoracion_destino,valoracion_momento,valoracion_justifica,hash_fila) VALUES ({vals_sql});\n"
                )
            fh.write("COMMIT;\n")
            fh.flush()
            try:
                os.fsync(fh.fileno())
            except Exception:
                pass
        os.replace(tmp_path, str(seed_path))
        tmp_path = None
    finally:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass

    seedjson_path = data_dir / "series.seed.json"
    seed = {
        "generated_at": None,
        "source_pdf": pdf_path.name,
        "sector": "SEGURO SOCIAL DE SALUD (EsSalud)",
        "fondo": "SEGURO SOCIAL DE SALUD (EsSalud)",
        "series": parsed,
    }
    import datetime

    seed["generated_at"] = datetime.datetime.utcnow().isoformat()
    safe_write_json(seedjson_path, seed)

    print("\nOutputs generated:")
    print(" - JSON:", json_path)
    print(" - CSV :", csv_path)
    print(" - SQL schema:", schema_path)
    print(" - SQL seed  :", seed_path)
    print(" - Seed JSON :", seedjson_path)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Ingest ANEXO 2 (PCD EsSalud) and produce normalized artifacts"
    )
    parser.add_argument("--pdf", "-p", help="Path to ESSALUD-PCD-ANEXO-2-TABLA.pdf", default=None)
    parser.add_argument(
        "--outdir",
        "-o",
        help="Output directory",
        default=str(Path.home() / "Desktop" / "PCD-EsSalud-OUT"),
    )
    parser.add_argument("--force", "-f", action="store_true", help="Force re-extraction")
    args = parser.parse_args(argv)

    try:
        pdf = find_pdf(args.pdf)
    except FileNotFoundError as e:
        print("Error:", e, file=sys.stderr)
        return 2

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    workdir = outdir / "work"
    workdir.mkdir(parents=True, exist_ok=True)
    txt_path = workdir / "anexo2_layout.txt"

    # We prefer pdftotext when available for best layout preservation, but
    # run_pdftotext() implements a pdfplumber fallback and will attempt to
    # install pdfplumber if necessary. Do not pre-exit here.

    if args.force or not txt_path.exists():
        print("Extracting text with pdftotext...")
        run_pdftotext(pdf, txt_path)
    else:
        print("Reusing existing extraction at", txt_path)

    parsed = parse_layout_text(txt_path)
    if not parsed:
        print("No rows parsed. Check PDF/layout/regex.", file=sys.stderr)
        return 4

    export_artifacts(parsed, pdf, outdir)
    return 0


if __name__ == "__main__":
    sys.exit(main())

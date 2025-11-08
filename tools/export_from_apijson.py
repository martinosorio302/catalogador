#!/usr/bin/env python3
"""Export CSV and SQL seed from api/data/essalud_pcd_anexo02.full.json.

Usage example (use forward slashes or double backslashes on Windows):
    python tools/export_from_apijson.py --src api/data/essalud_pcd_anexo02.full.json --outdir "C:/Users/USER/Desktop/PCD-EsSalud-OUT/data"
"""
import argparse
import json
from pathlib import Path
import csv
import hashlib


def hash_row(row):
    s = json.dumps(row, sort_keys=True, ensure_ascii=False)
    return hashlib.sha1(s.encode('utf-8')).hexdigest()


def load_json(path: Path):
    with path.open('r', encoding='utf-8') as f:
        return json.load(f)


def write_csv(rows, out: Path):
    out.parent.mkdir(parents=True, exist_ok=True)
    keys = ['fondo','codigo','titulo','valor','retencion_gestion','retencion_periferico','retencion_central','retencion_total','observaciones','hash']
    with out.open('w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        for r in rows:
            ret = r.get('retencion', {})
            w.writerow({
                'fondo': r.get('fondo',''),
                'codigo': r.get('codigo',''),
                'titulo': r.get('titulo',''),
                'valor': r.get('valor',''),
                'retencion_gestion': ret.get('gestion',0),
                'retencion_periferico': ret.get('periferico',0),
                'retencion_central': ret.get('central',0),
                'retencion_total': ret.get('total',0),
                'observaciones': r.get('observaciones',''),
                'hash': r.get('_hash', hash_row(r))
            })


def write_sql(rows, out: Path, table='retencion'):
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open('w', encoding='utf-8') as f:
        # simple CREATE TABLE (if needed)
        f.write('CREATE TABLE IF NOT EXISTS {} (fondo TEXT, codigo TEXT, titulo TEXT, valor TEXT, gestion INTEGER, periferico INTEGER, central INTEGER, total INTEGER, observaciones TEXT, hash TEXT);\n\n'.format(table))
        f.write('BEGIN TRANSACTION;\n')
        for r in rows:
            ret = r.get('retencion', {})
            codigo = (r.get('codigo','') or '').replace("'","''")
            titulo = (r.get('titulo','') or '').replace("'","''")
            fondo = (r.get('fondo','') or '').replace("'","''")
            valor = (r.get('valor','') or '').replace("'","''")
            obs = (r.get('observaciones','') or '').replace("'","''")
            h = r.get('_hash', hash_row(r))
            f.write("INSERT INTO {} (fondo,codigo,titulo,valor,gestion,periferico,central,total,observaciones,hash) VALUES ('{}','{}','{}','{}',{},{},{},{},'{}','{}');\n".format(
                table, fondo, codigo, titulo, valor, int(ret.get('gestion',0)), int(ret.get('periferico',0)), int(ret.get('central',0)), int(ret.get('total',0)), obs, h
            ))
        f.write('COMMIT;\n')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--src', default='api/data/essalud_pcd_anexo02.full.json')
    p.add_argument('--outdir', default='C:\\Users\\USER\\Desktop\\PCD-EsSalud-OUT\\data')
    args = p.parse_args()

    src = Path(args.src)
    outdir = Path(args.outdir)
    if not src.exists():
        print('Source not found:', src)
        return
    data = load_json(src)
    if isinstance(data, dict):
        # assume list of objects
        rows = data if isinstance(data, list) else list(data.values())
    else:
        rows = data

    csv_out = outdir / 'retencion_from_api.csv'
    sql_out = outdir / 'retencion_from_api_seed.sql'

    write_csv(rows, csv_out)
    write_sql(rows, sql_out)
    print('Wrote', csv_out)
    print('Wrote', sql_out)


if __name__ == '__main__':
    main()

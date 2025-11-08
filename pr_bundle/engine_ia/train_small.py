import json
from utils.http import post

URL = "http://127.0.0.1:8123/ml/train"

samples = [
    {"text": "expediente administrativo con fojas y anexos", "is_expediente": True},
    {"text": "historia clinica con anexos de laboratorio", "is_expediente": True},
    {"text": "carta simple dirigida a gerencia", "is_expediente": False},
    {"text": "informe medico de pagina unica", "is_expediente": False},
]

try:
    r = post(URL, json=samples, timeout=30)
    print("STATUS", r.status_code)
    try:
        print(json.dumps(r.json(), ensure_ascii=False, indent=2))
    except Exception:
        print(r.text)
except Exception as e:
    print("ERROR", e)

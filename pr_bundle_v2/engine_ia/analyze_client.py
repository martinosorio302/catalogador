import os
from utils.http import post

ENGINE_URL = os.environ.get("ENGINE_URL", "http://127.0.0.1:8123")

with open("sample_for_analyze.txt", "rb") as f:
    files = {"file": ("sample_for_analyze.txt", f, "application/pdf")}
    try:
        r = post(f"{ENGINE_URL}/analyze", files=files, timeout=30)
        print(r.text)
    except Exception as e:
        print("Error calling analyze endpoint:", e)

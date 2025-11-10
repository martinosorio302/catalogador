# Deployment & provisioning (Windows)

This file explains how to provision the Catalogador Windows service and run the ANEXO-2 ingestion locally.

Prerequisites (on the Windows host)
- Administrator privileges (required to install NSSM and configure the Windows service)
- PowerShell (default on Windows) with ExecutionPolicy that allows running local scripts: run as Administrator
- Optional: Chocolatey or winget to install Poppler; otherwise download Poppler manually

Files of interest
- `tools/provision_and_ingest_safe.ps1` — idempotent, self-elevating provisioning script that will:
  - create a service-specific venv under `C:\ProgramData\Catalogador\python_api\venv` (by default)
  - install Python dependencies into that venv (see `requirements-prod.txt`)
  - attempt to install Poppler if missing (choco / winget)
  - configure NSSM to run the FastAPI app as a Windows service
  - run the ANEXO-2 PDF ingester and the importer and POST /reload to the running service

Quick host steps (run in an elevated PowerShell as Administrator)

1. Open an elevated PowerShell (Run as Administrator)
2. From the repo root run:

```powershell
# Run provisioning (this script self-elevates; run as Admin)
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\provision_and_ingest_safe.ps1 -Force
```

3. The script will attempt to locate an ANEXO-2 PDF inside the repo (or you can pass a path). If it finds one it will ingest and import it and then call the running service to reload.

If you prefer to run only the ingest/import steps manually (non-elevated)

```powershell
# run inside your chosen python venv (or the repo venv)
python .\tools\ingest_anexo2.py --pdf "C:\path\to\ANEXO-2.pdf" --out "C:\some\dir\retencion_normalizada.json"
python .\tools\import_retencion.py "C:\some\dir\retencion_normalizada.json" --reload-host 127.0.0.1 --reload-port 8000
# then restart the service (requires admin):
# & 'C:\ProgramData\nssm\nssm.exe' restart Catalogador-PythonAPI
```

Poppler (pdftotext)
- Recommended for reliable PDF text extraction. The provisioning script will try choco or winget.
- If you cannot install it automatically, install it manually and ensure `pdftotext.exe` is in PATH.
  Downloads: https://github.com/oschwartz10612/poppler-windows/releases

Log locations
- NSSM-managed service stdout/stderr logs are configured under `C:\ProgramData\Catalogador\python_api\logs\` by the provisioning script.
- Repository-level copies of the API data are written to `./data/` (a copy of what the service uses).

CI
- A lightweight GitHub Actions workflow is included to run unit tests on push/PR. It does not install Poppler and therefore does not run full ingestion.

Support
- If the provisioning script fails on your host, capture the PowerShell output and the NSSM logs under ProgramData and open an issue with the logs attached.


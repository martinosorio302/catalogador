# Catalogador — Build & Packaging README

This README documents the local build and packaging steps used to produce the Electron desktop app for Catalogador EsSalud.

Quick steps (Windows PowerShell)

1) Build the frontend (Vite):

```powershell
cd C:\Users\USER\Desktop\Catalogador\src
npm ci
npm run build
```
## Running tests and service helpers

### Running tests locally

We run unit tests and a small integration test via pytest. The repo includes a
`tests/conftest.py` that (a) forces pytest to use a writable repository-local
temporary directory on Windows and (b) inserts the repository root into
`sys.path` so local packages (`tools`, `engine`) are preferred during tests.

Quick commands (from repo root):

Windows (PowerShell):
```powershell
# Use the service venv pytest when present
& 'C:\ProgramData\Catalogador\python_api\venv\Scripts\pytest.exe' -q

# Or use the helper
.\tools\run_tests.ps1
```

Linux/macOS or any system Python:
```bash
python -m pytest -q
```

CI: A GitHub Actions workflow is included in `.github/workflows/ci.yml` which
installs dependencies and runs the full test-suite on push/PR.

### Creating/Updating the NSSM service (Windows)

If you manage the service manually, use the helper `tools/generate_nssm_service.ps1`.
Run it as Administrator to create or update the NSSM service configuration:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\tools\generate_nssm_service.ps1 -ServiceName 'Catalogador-PythonAPI' -PythonExe 'C:\ProgramData\Catalogador\python_api\venv\Scripts\python.exe' -AppDir 'C:\ProgramData\Catalogador\python_api' -Port 8000

# Start service
nssm start Catalogador-PythonAPI
```

The `tools/rebuild_catalogador_api_service.ps1` script remains the higher-level
provisioning helper used to copy files to ProgramData, create the venv,
install dependencies and create the service.

2) From repo root, copy the built web assets and build Electron (unpacked):

```powershell
# optional: warn/clear common lock-holders
powershell -NoProfile -ExecutionPolicy Bypass -File tools\prepack.ps1 -ForceKill

# build UI and copy into root dist/web
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build_and_copy.ps1

# build unpacked app for testing
npx electron-builder --win --x64 --dir --config.directories.output=dist-electron

# When ready, build installer (NSIS)
npx electron-builder --win --x64 --config.directories.output=dist-electron --publish never
```

Notes & troubleshooting:
- Close Visual Studio Code and other indexers before packaging to avoid file-lock issues on `app.asar`.
- Ensure `build/icon.ico` is a valid multi-resolution icon if you want a custom application icon.
- If electron-builder complains about publish/provider, either set `"publish": []` in `package.json` or provide a valid `repository` and `publish` configuration.

If you want me to run the full pipeline (build + package + produce installer), reply with `RUN FULL PACKAGE` and I'll attempt it now.
# Catalogador EsSalud — Monorepo (maqueta)

Esta maqueta contiene un backend .NET 8 (simulado OCR/TRD) y un frontend Vite + React + Tailwind minimal.

Requisitos
- .NET SDK 8.0+
- Node.js 18+ y npm

Instalación rápida (PowerShell):

```powershell
cd C:\Users\USER\Desktop\Catalogador
.\scripts\setup_all.ps1
```

Ejecutar ambos servicios:

```powershell
cd C:\Users\USER\Desktop\Catalogador
.\scripts\run_all.ps1
```

Backend: http://localhost:5000 (Swagger)
Frontend: http://localhost:5173

Notas
- Si quieres empacar la app Electron, revisa `package.json` en la raíz y en `frontend` y sigue el flujo de electron-builder. En este repo hemos adaptado la UI para que cargue `dist/web` cuando exista.
# catalogador

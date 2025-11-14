## Catalogador — Entorno de trabajo Git (Guía rápida en español)

Este README explica cómo preparar un entorno de trabajo en Git para este
repositorio en Windows (PowerShell), incluyendo Git LFS, entorno Python (opcional
venv en ProgramData), ejecución de pruebas, creación de ramas y cómo generar
un Pull Request. Está pensado para desarrolladores que van a mantener,
probar y desplegar el API localmente.

Contenido rápido
- Requisitos
- Clonar el repositorio (SSH/HTTPS)
- Git LFS: instalación y uso
- Crear rama de trabajo y flujo Git (PowerShell)
- Entorno Python: venv local o venv en ProgramData (editable install)
- Instalar dependencias
- Ejecutar tests (pytest)
- Ejecutar la API localmente (uvicorn)
- Crear PR (GitHub CLI / web / API via PowerShell)
- Despliegue en Windows (scripts NSSM en `tools\`)
- Problemas comunes y soluciones

Requisitos previos
- Git (2.30+ recomendado)
- Git LFS (si trabajas con archivos grandes)
- Python 3.10+ (3.12 recomendado en CI)
- PowerShell (Windows PowerShell o PowerShell Core)
- Opcional: GitHub CLI (`gh`) para crear PR desde línea de comandos

1) Clonar el repositorio

Preferible: SSH (recomendado si ya agregaste tu llave pública a GitHub):

```powershell
# Clona el repo usando SSH
git clone git@github.com:martinosorio302/catalogador.git
cd catalogador
```

Alternativa: HTTPS

```powershell
git clone https://github.com/martinosorio302/catalogador.git
cd catalogador
```

--

Caso práctico: iniciar un repositorio local y empujar por primera vez
---------------------------------------------------------------

Si quieres crear el repositorio localmente desde cero (como hiciste) y
subir una rama inicial con tu ORCID en el nombre, aquí están los comandos
exactos en PowerShell (ejemplo):

```powershell
echo "# catalogador" >> README.md
git init
git add README.md
git commit -m "primer commit"
git branch -M orcid.org/0000-0002-9629-487X
git remote add origin https://github.com/martinosorio302/catalogador.git
git push -u origin orcid.org/0000-0002-9629-487X
```

Notas:
- Si usas HTTPS, Git pedirá tus credenciales (usuario/token). Para automatizar
	pushes sin introducir credenciales cada vez, considera configurar SSH y usar
	la URL SSH en `git remote add origin`.
- Si el push falla por objetos grandes, ejecuta `git lfs install` y `git lfs pull`.
- El nombre de rama con tu ORCID es válido; evita caracteres no permitidos por Git.


2) Configurar Git LFS

Si no lo tienes instalado, instálalo. En Windows puedes usar el instalador desde
https://git-lfs.com/ o choco:

```powershell
# con Chocolatey (si lo tienes)
choco install git-lfs -y
# inicializar en el repo (una sola vez)
git lfs install
# obtener objetos LFS para la rama actual
git lfs pull
```

3) Flujo básico de trabajo con ramas (PowerShell)

```powershell
# Crear y cambiar a una rama de trabajo
$branch = "fix/mi-cambio-descripcion"
git checkout -b $branch

# Trabaja, añade cambios y commitea
git add -A
git commit -m "feat: descripción breve del cambio"

# Empuja la rama al remoto
git push -u origin $branch
```

4) Entorno Python — opciones

a) Venv de desarrollo local (rápido, recomendado para devs):

```powershell
# desde la raíz del repo
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -U pip
pip install -e .
pip install -r requirements.txt
```

b) Editable install en ProgramData (para replicar el servicio en Windows):

Requiere privilegios de Administrador para crear carpetas bajo `C:\ProgramData`.

```powershell
# Ejecutar PowerShell como Administrador
$installRoot = 'C:\ProgramData\Catalogador\python_api'
New-Item -ItemType Directory -Path $installRoot -Force
python -m venv "$installRoot\venv"
& "$installRoot\venv\Scripts\Activate.ps1"
# Instalar el paquete en modo editable
pip install -U pip
cd C:\Users\USER\Desktop\Catalogador
pip install -e .
pip install -r requirements.txt
```

Nota: usar instalación editable (`pip install -e .`) permite editar código en el
repositorio y que el servicio lo cargue sin reinstalaciones frecuentes.

5) Ejecutar pruebas (pytest)

Existen helpers en `tools\` para Windows; ejemplo rápido:

```powershell
# Si instalaste un venv en ProgramData y contiene pytest
& 'C:\ProgramData\Catalogador\python_api\venv\Scripts\pytest.exe' -q

# O si estás en un venv local
.\.venv\Scripts\Activate.ps1
python -m pytest -q

# Helper incluido
.\tools\run_tests.ps1
```

6) Ejecutar la API localmente (desarrollo)

```powershell
# activar venv si corresponde
.\.venv\Scripts\Activate.ps1
# arranca uvicorn en 127.0.0.1:8000
python -m uvicorn api.main:app --host 127.0.0.1 --port 8000 --reload

# La app debería responder en http://127.0.0.1:8000
```

7) Crear un Pull Request

a) Usando GitHub CLI (`gh`) — recomendado si lo tienes:

```powershell
# autenticar (solo la primera vez)
gh auth login
# crear PR (interactivo o con flags)
gh pr create --title "fix(deploy): ..." --body-file .\reports\radiography_20251107.md --base main --head $branch
```

b) Alternativa: crear PR desde la web — visita la página del repo y sigue
el botón "Compare & pull request" después de empujar tu rama.

c) Crear PR por API (PowerShell + token) — ejemplo minimal:

```powershell
# Introduce un token con permisos `repo` (no lo pegues en scripts públicos)
$token = Read-Host -Prompt "Introduce tu GitHub PAT (texto claro)"
$payload = @{
	title = 'fix(deploy): despliegue y atomicidad'
	head = $branch
	base = 'main'
	body = Get-Content -Raw .\reports\radiography_20251107.md
} | ConvertTo-Json -Depth 6

Invoke-RestMethod -Method Post -Uri "https://api.github.com/repos/martinosorio302/catalogador/pulls" -Headers @{ Authorization = "token $token"; "User-Agent" = "catalogador-agent" } -Body $payload -ContentType 'application/json'
```

8) Despliegue en Windows (NSSM helper scripts)

El repo incluye scripts PowerShell en `tools\` para copiar artefactos,
crear/actualizar el venv en ProgramData y configurar el servicio NSSM. Los
principales scripts son:

- `tools\final_deploy_catalogador.ps1` — despliegue final (copia a ProgramData,
	crea el venv, instala dependencias y configura NSSM).
- `tools\auto_redeploy_catalogador.ps1` — redeploy automático/rollback helper.
- `tools\enable_service_autostart.ps1` — habilita arranque automático del
	servicio Windows.

Ejecución típica (como Administrador):

```powershell
# Ejecutar con elevación
Set-ExecutionPolicy Bypass -Scope Process -Force
.\tools\final_deploy_catalogador.ps1 -Mode B -Force

# Iniciar el servicio
nssm start Catalogador-PythonAPI
```

9) Endpoint de administración — reload

El proyecto expone un endpoint admin POST `/reload` protegido opcionalmente por
la cabecera `X-Admin-Token`. Para recargar datos de configuración o TRD desde
los scripts, exporta `ADMIN_RELOAD_TOKEN` o pásalo como header.

10) Buenas prácticas Git

- Hacer commits pequeños y atómicos.
- Escribir mensajes claros (tipo: feat:, fix:, docs:, chore:).
- Mantener la rama `main` como origen estable; abrir PRs y esperar CI.

11) Resolución de problemas comunes

- Error: "PermissionError" al escribir archivos en Windows
	- Causa: otro proceso (antivirus, editor o servicio) bloqueó el fichero.
	- Solución: cerrar VSCode, reintentar; los scripts del repo implementan
		reintentos y escritura atómica. Ejecutar despliegue como administrador si
		copias en `C:\ProgramData`.

- Error: `git push` falla por objetos grandes
	- Solución: ejecutar `git lfs install` y `git lfs pull`, o contactar al
		administrador del repo para migrar historial a LFS si es necesario.

- Error: PR creation fails in PowerShell with 401/403
	- Verifica que el token tenga permisos `repo` y que lo estás usando correctamente.

12) Comandos útiles (resumen)

```powershell
# Activar venv local
.\.venv\Scripts\Activate.ps1

# Instalar deps
pip install -e .
pip install -r requirements.txt

# Ejecutar tests
python -m pytest -q

# Ejecutar API en desarrollo
python -m uvicorn api.main:app --host 127.0.0.1 --port 8000 --reload

# Crear y empujar rama
git checkout -b fix/mi-cambio
git add -A
git commit -m "fix: ..."
git push -u origin fix/mi-cambio

# Crear PR con gh
gh pr create --title "fix(...)" --body-file .\reports\radiography_20251107.md --base main --head fix/mi-cambio
```

13) ¿Necesitas que haga algo por ti?

- Puedo:
	- Ejecutar la suite de tests en el entorno que me indiques.
	- Intentar crear el PR si me proporcionas un PAT (temporal) o si ejecutas el
		comando `gh pr create` localmente y pegas el enlace.

Contacto rápido
- Si algún comando falla en tu máquina, copia aquí el error y lo depuramos.

---
Archivo de referencia: `tools\` contiene scripts de despliegue y helpers para
Windows. Para preguntas específicas sobre deploy o CI, indícame qué host y
privilegios tienes y lo configuro contigo.

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

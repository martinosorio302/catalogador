# 🔧 GUÍA DE SOLUCIÓN DE PROBLEMAS - CATALOGADOR ESSALUD

## 📋 Índice

1. [Problemas de Instalación](#problemas-de-instalación)
2. [Problemas de Ejecución](#problemas-de-ejecución)
3. [Problemas de Dependencias](#problemas-de-dependencias)
4. [Problemas de Red/Puertos](#problemas-de-redpuertos)
5. [Problemas de Deployment Windows](#problemas-de-deployment-windows)
6. [Problemas de Tests](#problemas-de-tests)
7. [Problemas de Datos](#problemas-de-datos)
8. [Logs y Diagnóstico](#logs-y-diagnóstico)

---

## 🔴 Problemas de Instalación

### ❌ Error: "python: command not found"

**Causa:** Python no está instalado o no está en el PATH

**Solución:**
```bash
# Windows: Descargar e instalar Python desde python.org
# Durante instalación, marcar "Add Python to PATH"

# Linux/macOS:
sudo apt install python3 python3-pip  # Ubuntu/Debian
brew install python3                  # macOS con Homebrew

# Verificar instalación
python --version
```

---

### ❌ Error: "node: command not found"

**Causa:** Node.js no está instalado

**Solución:**
```bash
# Windows: Descargar desde nodejs.org
# Linux: https://nodejs.org/en/download/package-manager/
# macOS:
brew install node

# Verificar
node --version
npm --version
```

---

### ❌ Error: Git LFS objects not found

**Causa:** Git LFS no instalado o no inicializado

**Solución:**
```bash
# Instalar Git LFS
# Windows: https://git-lfs.github.com/
# Linux:
sudo apt install git-lfs  # Ubuntu/Debian

# Inicializar
git lfs install

# Descargar objetos LFS
git lfs pull
```

---

## 🔴 Problemas de Ejecución

### ❌ Error: "ModuleNotFoundError: No module named 'fastapi'"

**Causa:** Dependencias Python no instaladas

**Solución:**
```bash
# Activar entorno virtual
.venv/Scripts/Activate.ps1  # Windows
source .venv/bin/activate     # Linux/macOS

# Instalar dependencias
pip install -r requirements.txt

# Verificar instalación
pip list | grep fastapi
```

---

### ❌ Error: API no responde en http://127.0.0.1:8000

**Causa:** API no está ejecutándose o puerto ocupado

**Solución:**
```bash
# 1. Verificar si el proceso está corriendo
# Windows:
netstat -ano | findstr :8000

# Linux/macOS:
lsof -i :8000

# 2. Si puerto ocupado, matar proceso
# Windows:
taskkill /PID <PID> /F

# Linux/macOS:
kill -9 <PID>

# 3. Iniciar API en puerto alternativo
python -m uvicorn api.main:app --port 8001

# 4. Verificar logs
python -m uvicorn api.main:app --log-level debug
```

---

### ❌ Error: Frontend muestra "Cannot connect to backend"

**Causa:** API backend no está corriendo o URL incorrecta

**Solución:**
```bash
# 1. Verificar que API esté corriendo
curl http://127.0.0.1:8000/health

# 2. Verificar configuración de proxy en vite.config.ts
cat src/vite.config.ts

# 3. Reiniciar ambos servicios
# Terminal 1: API
python -m uvicorn api.main:app --reload

# Terminal 2: Frontend
cd src && npm run dev
```

---

## 🔴 Problemas de Dependencias

### ❌ Error: "npm ERR! code ELIFECYCLE"

**Causa:** Node modules corruptos o conflictos de versiones

**Solución:**
```bash
cd src

# Eliminar node_modules y cache
rm -rf node_modules package-lock.json
npm cache clean --force

# Reinstalar
npm install

# Si persiste, usar npm ci
npm ci
```

---

### ❌ Error: "pip install fails with compilation error"

**Causa:** Falta compilador C/C++ para extensiones nativas

**Solución:**
```bash
# Windows: Instalar Visual Studio Build Tools
# https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022

# Linux:
sudo apt install build-essential python3-dev

# macOS:
xcode-select --install

# Alternativa: usar wheels precompilados
pip install --only-binary :all: <package>
```

---

### ❌ Error: "ImportError: DLL load failed" (Windows)

**Causa:** Faltan Visual C++ Redistributables

**Solución:**
```powershell
# Descargar e instalar:
# https://aka.ms/vs/17/release/vc_redist.x64.exe

# Reiniciar PowerShell después de instalar
```

---

## 🔴 Problemas de Red/Puertos

### ❌ Error: "Address already in use"

**Causa:** Puerto ya ocupado por otro proceso

**Solución:**
```bash
# Identificar proceso
# Windows:
netstat -ano | findstr :<PORT>
taskkill /PID <PID> /F

# Linux/macOS:
lsof -ti:<PORT> | xargs kill -9

# O usar puerto alternativo
python -m uvicorn api.main:app --port 8001
cd src && npx vite --port 5174
```

---

### ❌ Error: "Connection refused"

**Causa:** Firewall bloqueando conexiones

**Solución:**
```powershell
# Windows: Agregar regla de firewall
New-NetFirewallRule -DisplayName "Catalogador API" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow

# Linux:
sudo ufw allow 8000/tcp

# Verificar que API escucha en todas las interfaces
python -m uvicorn api.main:app --host 0.0.0.0 --port 8000
```

---

## 🔴 Problemas de Deployment Windows

### ❌ Error: "Access denied" en PowerShell scripts

**Causa:** Política de ejecución restrictiva

**Solución:**
```powershell
# Ejecutar PowerShell como Administrador
Set-ExecutionPolicy Bypass -Scope Process -Force

# O permanente (requiere Admin)
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine

# Ejecutar script
.\tools\final_deploy_catalogador.ps1 -Mode B
```

---

### ❌ Error: "NSSM service won't start"

**Causa:** Configuración incorrecta o permisos

**Solución:**
```powershell
# Verificar configuración del servicio
nssm edit Catalogador-PythonAPI

# Ver logs del servicio
nssm status Catalogador-PythonAPI

# Logs de NSSM
Get-Content C:\ProgramData\Catalogador\python_api\logs\service_stderr.log -Tail 50

# Reiniciar servicio
nssm restart Catalogador-PythonAPI

# Si falla, eliminar y recrear
nssm remove Catalogador-PythonAPI confirm
.\tools\generate_nssm_service.ps1
```

---

### ❌ Error: "PermissionError" al escribir archivos

**Causa:** Otro proceso tiene el archivo abierto (antivirus, VSCode, etc.)

**Solución:**
```powershell
# Cerrar VSCode y otros editores
# Pausar antivirus temporalmente

# Usar escritura atómica con reintentos (ya implementado)
python tools/import_retencion.py --src "data.json"

# Si persiste, ejecutar como Administrador
```

---

## 🔴 Problemas de Tests

### ❌ Error: "pytest: command not found"

**Causa:** pytest no instalado

**Solución:**
```bash
pip install pytest

# O reinstalar todas las dependencias
pip install -r requirements.txt
```

---

### ❌ Error: Tests fallan con "ModuleNotFoundError"

**Causa:** PYTHONPATH no configurado correctamente

**Solución:**
```bash
# Opción 1: Ejecutar desde raíz del repo
cd /path/to/catalogador
python -m pytest -v

# Opción 2: Instalar paquete en modo editable
pip install -e .

# Opción 3: Configurar PYTHONPATH
export PYTHONPATH=/path/to/catalogador:$PYTHONPATH  # Linux/macOS
$env:PYTHONPATH="/path/to/catalogador"               # Windows PowerShell
```

---

### ❌ Error: Test timeout en Windows

**Causa:** Sistema lento o antivirus escaneando archivos

**Solución:**
```bash
# Aumentar timeout
pytest --timeout=60

# Excluir directorio de tests del antivirus
# Agregar a exclusiones: C:\path\to\catalogador\.pytest_work
```

---

## 🔴 Problemas de Datos

### ❌ Error: "TRD data not found"

**Causa:** Archivos de datos TRD faltantes

**Solución:**
```bash
# Verificar existencia
ls -l engine/data/trd.json
ls -l api/data/essalud_pcd_anexo02.full.json
ls -l data/essalud_pcd_anexo02.full.json

# Si faltan, usar datos de ejemplo del repo
git checkout engine/data/trd.json
git checkout api/data/essalud_pcd_anexo02.full.json

# O importar datos actualizados
python tools/import_retencion.py --src "new_data.json"
```

---

### ❌ Error: "Invalid JSON structure" al importar

**Causa:** Formato JSON incorrecto

**Solución:**
```bash
# Validar JSON
python -m json.tool < data.json

# Ver estructura esperada
cat api/data/essalud_pcd_anexo02.full.json | head -50

# Importar con validación
python tools/import_retencion.py --src "data.json" --no-reload
```

---

## 🔴 Logs y Diagnóstico

### 📊 Habilitar modo debug

```bash
# API con logs detallados
python -m uvicorn api.main:app --log-level debug --reload

# Ver todos los logs
tail -f logs/*.log  # Linux/macOS
Get-Content logs\*.log -Wait  # Windows
```

---

### 📊 Verificar estado del sistema

```bash
# Health check API
curl http://127.0.0.1:8000/health

# Verificar endpoints
curl http://127.0.0.1:8000/docs

# Test clasificación
curl -X POST http://127.0.0.1:8000/classify \
  -H "Content-Type: application/json" \
  -d '{"asunto_unidad":"test","titulo":"documento de prueba"}'
```

---

### 📊 Información del sistema

```bash
# Versiones instaladas
python --version
node --version
npm --version
dotnet --version

# Paquetes Python
pip list

# Paquetes Node
cd src && npm list --depth=0

# Estado del servicio (Windows)
nssm status Catalogador-PythonAPI
```

---

## 🆘 Procedimiento de Emergencia

Si todo falla, seguir estos pasos:

### 1. Backup de datos
```bash
# Copiar datos importantes
cp -r api/data/ backup/
cp -r engine/data/ backup/
```

### 2. Limpieza completa
```bash
# Eliminar entornos virtuales
rm -rf .venv venv

# Eliminar node_modules
cd src && rm -rf node_modules
cd .. && rm -rf node_modules

# Eliminar cache
rm -rf __pycache__ */__pycache__ */*/__pycache__
rm -rf .pytest_cache .pytest_work
```

### 3. Reinstalación desde cero
```bash
# Python
python -m venv .venv
source .venv/bin/activate  # Linux/macOS
.venv\Scripts\Activate.ps1  # Windows
pip install -r requirements.txt

# Node
cd src
npm install
cd ..
```

### 4. Verificación
```bash
# Tests
python -m pytest -v

# API
python -m uvicorn api.main:app

# Frontend
cd src && npm run dev
```

---

## 📞 Contacto de Soporte

Si el problema persiste después de intentar las soluciones anteriores:

1. **Revisar logs completos**
2. **Documentar el error exacto** (captura de pantalla)
3. **Indicar sistema operativo y versiones**
4. **Listar pasos para reproducir**
5. **Crear issue en GitHub** con la información recopilada

---

## ✅ Verificación de Estado

Antes de reportar un problema, ejecutar este checklist:

```bash
# Checklist rápido
python --version          # ✅ 3.10+
node --version           # ✅ 18+
pip list | grep fastapi  # ✅ Instalado
ls api/data/            # ✅ Datos presentes
python -m pytest -v     # ✅ 11/11 tests
curl http://127.0.0.1:8000/health  # ✅ {"ok":true}
```

Si todos los checks pasan, el sistema está operativo. ✅

---

**Actualizado:** 2025-11-12  
**Versión:** 1.0.0

# 🪟 GUÍA DE INICIO RÁPIDO - WINDOWS

## ⚠️ IMPORTANTE: Ubicación del Repositorio

**Primero, necesitas saber dónde está tu repositorio clonado.**

Comandos para encontrarlo:
```powershell
# Buscar el repositorio
Get-ChildItem -Path C:\ -Filter "catalogador" -Directory -Recurse -ErrorAction SilentlyContinue

# O si lo clonaste en tu usuario:
Get-ChildItem -Path $env:USERPROFILE -Filter "catalogador" -Directory -Recurse -ErrorAction SilentlyContinue
```

Ubicaciones comunes:
- `C:\Users\USER\Documents\catalogador`
- `C:\Users\USER\Desktop\catalogador`
- `C:\Users\USER\catalogador`
- `C:\Projects\catalogador`

---

## 🚀 PASOS PARA EJECUTAR (Windows)

### Paso 1: Navegar al Repositorio

```powershell
# ⚠️ REEMPLAZA esta ruta con la ubicación real de tu repositorio
cd C:\Users\USER\Desktop\catalogador

# Verificar que estás en el lugar correcto
ls
# Deberías ver: api, src, tools, etc.
```

### Paso 2: Verificar Requisitos

```powershell
# Verificar Python
python --version
# Debe mostrar: Python 3.10 o superior

# Verificar Node.js
node --version
# Debe mostrar: v18.0 o superior

# Verificar npm
npm --version
```

---

## 🎯 OPCIÓN 1: API Backend (Más Simple)

### Instalación (Solo primera vez)

```powershell
# En la raíz del repositorio
cd C:\Users\USER\Desktop\catalogador

# Crear entorno virtual
python -m venv .venv

# Activar entorno virtual
.\.venv\Scripts\Activate.ps1

# Si da error de permisos, ejecutar primero:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Instalar dependencias
pip install -r requirements.txt
```

### Ejecución

```powershell
# Activar entorno virtual (si no está activo)
.\.venv\Scripts\Activate.ps1

# Iniciar API
python -m uvicorn api.main:app --host 127.0.0.1 --port 8000 --reload
```

### Verificar

Abre tu navegador en: **http://127.0.0.1:8000/docs**

Deberías ver la interfaz Swagger con todos los endpoints.

---

## 🎯 OPCIÓN 2: Frontend + Backend

### Instalación Frontend (Solo primera vez)

```powershell
# Navegar a la carpeta src
cd C:\Users\USER\Desktop\catalogador\src

# Instalar dependencias
npm install

# Volver a raíz
cd ..
```

### Ejecución

**Terminal 1 - Backend:**
```powershell
cd C:\Users\USER\Desktop\catalogador
.\.venv\Scripts\Activate.ps1
python -m uvicorn api.main:app --reload
```

**Terminal 2 - Frontend:**
```powershell
cd C:\Users\USER\Desktop\catalogador\src
npm run dev
```

### Verificar

- **API Backend:** http://127.0.0.1:8000/docs
- **Frontend:** http://localhost:5173

---

## 🎯 OPCIÓN 3: Aplicación Electron (Desktop)

### Instalación (Solo primera vez)

```powershell
# En la raíz del repositorio
cd C:\Users\USER\Desktop\catalogador

# Instalar dependencias Electron
npm install
```

### Ejecución

```powershell
# Desarrollo con hot-reload
npm run electron:dev
```

Se abrirá una ventana de la aplicación de escritorio.

---

## 🧪 PRUEBAS Y VALIDACIÓN

### Test de Health Check

```powershell
# PowerShell usa Invoke-WebRequest en lugar de curl
Invoke-WebRequest -Uri "http://127.0.0.1:8000/health" -Method GET | Select-Object -ExpandProperty Content
```

**Respuesta esperada:** `{"ok":true}`

### Test de Clasificación

```powershell
# Crear archivo JSON temporal con los datos
$body = @{
    asunto_unidad = "CONSEJO DIRECTIVO"
    titulo = "ACTAS DE SESIONES"
} | ConvertTo-Json

# Hacer la petición POST
Invoke-RestMethod -Uri "http://127.0.0.1:8000/classify" -Method POST -Body $body -ContentType "application/json"
```

**Respuesta esperada:** JSON con la clasificación TRD

### Ejecutar Tests

```powershell
cd C:\Users\USER\Desktop\catalogador
.\.venv\Scripts\Activate.ps1
python -m pytest -v
```

**Resultado esperado:** `11 passed`

---

## ❌ SOLUCIÓN DE ERRORES COMUNES

### Error: "Cannot find path"

**Problema:** Estás en el directorio equivocado

**Solución:**
```powershell
# Navegar a la ubicación correcta
cd C:\Users\USER\Desktop\catalogador

# O donde hayas clonado el repo
# Verifica con:
Get-Location
```

### Error: "Activate.ps1 cannot be loaded"

**Problema:** Política de ejecución de PowerShell

**Solución:**
```powershell
# Ejecutar PowerShell como Administrador y ejecutar:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# O temporalmente:
Set-ExecutionPolicy Bypass -Scope Process
```

### Error: "[WinError 10013] Intento de acceso a un socket"

**Problema:** No tienes permisos o el puerto está ocupado

**Soluciones:**

1. **Ejecutar PowerShell como Administrador:**
   - Click derecho en PowerShell → "Ejecutar como administrador"

2. **Usar otro puerto:**
   ```powershell
   python -m uvicorn api.main:app --host 127.0.0.1 --port 8001 --reload
   ```

3. **Verificar si el puerto está ocupado:**
   ```powershell
   netstat -ano | findstr :8000
   
   # Si hay un proceso, matarlo (usa el PID del resultado):
   taskkill /PID <numero_pid> /F
   ```

4. **No ejecutar desde C:\Windows\System32:**
   ```powershell
   # NUNCA ejecutes desde System32
   # Siempre navega a tu repositorio primero
   cd C:\Users\USER\Desktop\catalogador
   ```

### Error: "Missing script"

**Problema:** No estás en el directorio correcto

**Solución:**
```powershell
# Para npm run dev:
cd C:\Users\USER\Desktop\catalogador\src
npm run dev

# Para npm run electron:dev:
cd C:\Users\USER\Desktop\catalogador
npm run electron:dev
```

### Error: "Module not found"

**Problema:** Dependencias no instaladas

**Solución:**
```powershell
# Python
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Node.js (en src/)
cd src
npm install

# Node.js (en raíz, para Electron)
cd ..
npm install
```

---

## 📝 SCRIPT DE INICIO AUTOMÁTICO

Crea un archivo `start.ps1` en la raíz del repositorio:

```powershell
# start.ps1
# Script de inicio para Catalogador EsSalud

param(
    [string]$Mode = "api"  # api, frontend, o electron
)

$RepoRoot = $PSScriptRoot

Write-Host "🚀 Iniciando Catalogador EsSalud..." -ForegroundColor Green
Write-Host "📂 Repositorio: $RepoRoot" -ForegroundColor Cyan

switch ($Mode) {
    "api" {
        Write-Host "🔧 Modo: API Backend" -ForegroundColor Yellow
        Set-Location $RepoRoot
        & "$RepoRoot\.venv\Scripts\Activate.ps1"
        python -m uvicorn api.main:app --host 127.0.0.1 --port 8000 --reload
    }
    "frontend" {
        Write-Host "🔧 Modo: Frontend" -ForegroundColor Yellow
        Set-Location "$RepoRoot\src"
        npm run dev
    }
    "electron" {
        Write-Host "🔧 Modo: Electron Desktop" -ForegroundColor Yellow
        Set-Location $RepoRoot
        npm run electron:dev
    }
    default {
        Write-Host "❌ Modo desconocido: $Mode" -ForegroundColor Red
        Write-Host "Uso: .\start.ps1 -Mode [api|frontend|electron]" -ForegroundColor Yellow
    }
}
```

### Uso del Script:

```powershell
# Iniciar API
.\start.ps1 -Mode api

# Iniciar Frontend
.\start.ps1 -Mode frontend

# Iniciar Electron
.\start.ps1 -Mode electron
```

---

## 🔍 CHECKLIST DE VERIFICACIÓN

Antes de reportar un problema, verifica:

- [ ] Estás en el directorio del repositorio (NO en System32)
- [ ] Python está instalado (`python --version`)
- [ ] Node.js está instalado (`node --version`)
- [ ] Entorno virtual creado (carpeta `.venv` existe)
- [ ] Entorno virtual activado (prompt muestra `(.venv)`)
- [ ] Dependencias Python instaladas (`pip list | findstr fastapi`)
- [ ] Dependencias Node instaladas (carpeta `node_modules` existe)
- [ ] PowerShell con permisos correctos
- [ ] Puerto 8000 disponible

---

## 🆘 AYUDA RÁPIDA

**Si nada funciona, reinstalar desde cero:**

```powershell
# 1. Navegar al repositorio
cd C:\Users\USER\Desktop\catalogador

# 2. Limpiar todo
Remove-Item -Recurse -Force .venv -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force node_modules -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force src\node_modules -ErrorAction SilentlyContinue

# 3. Reinstalar Python
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# 4. Reinstalar Node (src)
cd src
npm install
cd ..

# 5. Reinstalar Node (raíz)
npm install

# 6. Verificar
python -m pytest -v
```

---

## 📞 COMANDOS DE DIAGNÓSTICO

```powershell
# Información del sistema
systeminfo | findstr /C:"OS Name" /C:"OS Version"

# Versiones instaladas
python --version
node --version
npm --version

# Ubicación actual
Get-Location

# Listar archivos
Get-ChildItem

# Procesos en puerto 8000
netstat -ano | findstr :8000

# Variables de entorno
$env:PYTHONPATH
$env:NODE_ENV
```

---

**Última actualización:** 2025-11-12  
**Plataforma:** Windows 10/11  
**PowerShell:** 7.x recomendado

# Catalogador EsSalud - Guía de Inicio Rápido

## ⚠️ IMPORTANTE: Actualizar Repositorio

Si tienes una copia local antigua, **primero actualiza el repositorio**:

```powershell
# En PowerShell
git pull origin copilot/fix-integration-issues-vscode
```

**Nota**: Los directorios `backend/`, `frontend/`, `src/`, `electron/` fueron eliminados. Si aún los ves, ejecuta `git pull` para actualizar.

---

## 🚀 Inicio Rápido (Windows)

### Opción A: Usar Script Automático (Recomendado)

```powershell
# 1. Ejecutar script de compilación
.\scripts\build_all.ps1

# 2. Ejecutar la aplicación
.\Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe
```

### Opción B: Compilación Manual

#### Paso 1: Activar Entorno Python

```powershell
# Activar virtual environment
.\.venv\Scripts\Activate.ps1

# Instalar dependencias Python
pip install -r requirements.txt -r dev-requirements.txt -e .
```

#### Paso 2: Compilar Aplicación WPF

```powershell
# Compilar en modo Release
dotnet build Catalogador.sln -c Release
```

**Ubicación del ejecutable**:
`Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe`

#### Paso 3: Instalar Servicio de Backend (Opcional)

```powershell
# Ejecutar como Administrador
.\tools\install_windows_service.ps1
```

---

## 🔧 Compilar Instalador InnoSetup

### Requisitos

1. **Inno Setup 6.x** instalado
   - Descargar de: https://jrsoftware.org/isdl.php

2. **WPF compilada** en modo Release

### Pasos

```powershell
# 1. Compilar WPF (si no lo has hecho)
dotnet build Catalogador.sln -c Release

# 2. Cambiar al directorio del instalador
cd installer

# 3. Compilar con Inno Setup
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" catalogador_setup.iss
```

**Salida**: `installer\output\CatalogadorEsSalud_Setup_1.0.0.exe`

---

## 📋 Verificación

### Backend Python

```powershell
# Iniciar backend manualmente
python -m uvicorn api.main:app --reload

# En otro terminal, probar endpoint
curl http://127.0.0.1:8000/health
# Respuesta esperada: {"status":"ok"}
```

### Tests Python

```powershell
# Ejecutar tests
python -m pytest -v

# Respuesta esperada: 11/11 tests passing
```

### Aplicación WPF

```powershell
# Ejecutar aplicación
.\Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe
```

**Verificar**:
- ✅ Ventana se abre correctamente
- ✅ Indicador de conexión muestra estado del backend
- ✅ Tabs (Documentos, TRD, Inventario) visibles

---

## 🐛 Solución de Problemas

### Error: "backend/Program.cs" se está compilando

**Causa**: Tienes una copia local antigua del repositorio.

**Solución**:
```powershell
# Actualizar repositorio
git pull origin copilot/fix-integration-issues-vscode

# Si hay conflictos, hacer reset
git reset --hard origin/copilot/fix-integration-issues-vscode
```

### Error: "The term '>' is not recognized"

**Causa**: Intentaste ejecutar múltiples comandos en una línea con `>`.

**Solución**: Ejecuta los comandos **uno por uno**:
```powershell
# ❌ Incorrecto
dotnet build Catalogador.sln -c Release > cd installer > ...

# ✅ Correcto
dotnet build Catalogador.sln -c Release
cd installer
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" catalogador_setup.iss
```

### Error: "dotnet: No se encontró el proyecto"

**Causa**: Estás en el directorio incorrecto.

**Solución**:
```powershell
# Ir al directorio raíz del repositorio
cd C:\Users\USER\Desktop\Catalogador

# Verificar que Catalogador.sln existe
ls Catalogador.sln
```

### Error: "Inno Setup no está instalado"

**Solución**:
1. Descargar de: https://jrsoftware.org/isdl.php
2. Instalar con opciones por defecto
3. Reiniciar PowerShell

### Backend no inicia

**Verificar**:
```powershell
# 1. Python está en PATH
python --version
# Esperado: Python 3.11.x o superior

# 2. Dependencias instaladas
pip list | Select-String -Pattern "fastapi|uvicorn"

# 3. Reinstalar dependencias si es necesario
pip install -r requirements.txt --force-reinstall
```

---

## 📚 Documentación Adicional

- **Instalador**: Ver `installer/BUILD_INSTRUCTIONS.md`
- **VSCode**: Ver `VSCODE_SETUP.md`
- **Arquitectura**: Ver `ARCHITECTURAL_ANALYSIS.md`
- **Cambios**: Ver `CHANGELOG.md`

---

## 🎯 Flujo de Trabajo Completo

### Para Desarrollo

```powershell
# 1. Activar entorno
.\.venv\Scripts\Activate.ps1

# 2. Iniciar backend (terminal 1)
python -m uvicorn api.main:app --reload

# 3. Compilar y ejecutar WPF (terminal 2)
dotnet build Catalogador.sln -c Debug
.\Catalogador.App\bin\Debug\net8.0-windows\CatalogadorEsSalud.exe
```

### Para Producción

```powershell
# 1. Compilar aplicación
dotnet build Catalogador.sln -c Release

# 2. Instalar servicio
.\tools\install_windows_service.ps1

# 3. Compilar instalador
cd installer
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" catalogador_setup.iss

# 4. Distribuir
# installer\output\CatalogadorEsSalud_Setup_1.0.0.exe
```

---

## ✅ Checklist de Verificación

Antes de crear el instalador, verifica:

- [ ] Backend inicia sin errores: `python -m uvicorn api.main:app --reload`
- [ ] Tests pasan: `python -m pytest -v` (11/11)
- [ ] WPF compila: `dotnet build Catalogador.sln -c Release` (sin errores)
- [ ] WPF ejecuta: Aplicación abre correctamente
- [ ] Conexión backend: Indicador muestra "Conectado"
- [ ] Inno Setup instalado: Versión 6.x

---

**Última actualización**: 2025-11-11  
**Versión**: 1.0.0

# Catalogador EsSalud - Sistema de Gestión Documental

**Aplicación de escritorio Windows** para catalogación, OCR, clasificación y gestión de documentos con TRD (Tabla de Retención Documental).

---

## 🏗️ Arquitectura

El sistema utiliza una arquitectura **Windows nativa** con backend Python y frontend .NET:

```
┌─────────────────────────────────────────┐
│  Catalogador.App (WPF .NET 8)          │  ← Interfaz de Usuario
│  - Carga de documentos                  │
│  - Visualización TRD                    │
│  - Exportación a Excel                  │
└────────────┬────────────────────────────┘
             │ HTTP (127.0.0.1:8000)
             ↓
┌─────────────────────────────────────────┐
│  Python FastAPI Backend                 │  ← Servicio Windows (NSSM)
│  - OCR con PyMuPDF                      │
│  - Clasificación TRD                    │
│  - Procesamiento PDF                    │
│  - API REST                             │
└────────────┬────────────────────────────┘
             │
             ↓
┌─────────────────────────────────────────┐
│  Motor TRD (engine/)                    │  ← Lógica de Negocio
│  - Clasificación documental             │
│  - Reglas de retención                  │
│  - Validación de series                 │
└─────────────────────────────────────────┘
```

---

## 🚀 Inicio Rápido

### Para Usuarios Finales

1. **Instalar el servicio de backend:**
   ```powershell
   # Ejecutar como Administrador
   .\tools\install_windows_service.ps1
   ```

2. **Compilar la aplicación WPF:**
   ```powershell
   dotnet build Catalogador.sln -c Release
   ```

3. **Ejecutar la aplicación:**
   - Abrir `Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe`
   - O desde Visual Studio: F5

### Para Desarrolladores

Ver [VSCODE_SETUP.md](VSCODE_SETUP.md) para configuración completa del entorno de desarrollo.

**Configuración rápida:**

```powershell
# 1. Clonar el repositorio
git clone https://github.com/martinosorio302/catalogador.git
cd catalogador

# 2. Configurar Python
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt -r dev-requirements.txt
pip install -e .

# 3. Ejecutar tests
python -m pytest -v

# 4. Iniciar backend (desarrollo)
python -m uvicorn api.main:app --reload --host 127.0.0.1 --port 8000

# 5. Compilar WPF app (en otra terminal)
dotnet build Catalogador.sln
```

---

## 📁 Estructura del Proyecto

```
Catalogador/
│
├── api/                          # Backend FastAPI (Python)
│   ├── main.py                   # Punto de entrada
│   ├── routers/                  # Endpoints REST
│   ├── services/                 # Lógica de negocio
│   └── models/                   # Modelos de datos
│
├── engine/                       # Motor TRD (Python)
│   └── trd.py                    # Clasificación documental
│
├── Catalogador.App/              # Aplicación Desktop (WPF .NET 8)
│   ├── Views/                    # Interfaces XAML
│   ├── Services/                 # Cliente HTTP API
│   ├── Models/                   # Modelos de datos
│   └── Helpers/                  # Utilidades
│
├── tools/                        # Scripts de Servicio Windows
│   ├── install_windows_service.ps1
│   ├── uninstall_service.ps1
│   ├── start_service.ps1
│   └── stop_service.ps1
│
├── tests/                        # Suite de Pruebas (pytest)
│   └── test_*.py                 # 11 tests (todos passing)
│
├── scripts/                      # Scripts de Validación
│   ├── validate_setup.sh
│   └── test_backend_startup.sh
│
└── .vscode/                      # Configuración VSCode
    ├── settings.json
    ├── tasks.json
    └── launch.json
```

---

## 🔧 Tecnologías

### Backend
- **Python 3.11+**
- FastAPI - Framework web moderno
- uvicorn - Servidor ASGI
- PyMuPDF (fitz) - Procesamiento PDF y OCR
- pdfplumber - Extracción de texto
- Pydantic - Validación de datos

### Frontend
- **.NET 8**
- WPF (Windows Presentation Foundation)
- XAML - Diseño de interfaz
- ClosedXML - Exportación Excel
- System.Net.Http - Cliente API

### Despliegue
- **NSSM** - Windows Service Manager
- **InnoSetup** - Instalador Windows (próximamente)

---

## 📝 Gestión del Servicio Windows

### Instalar el Servicio

```powershell
# Ejecutar como Administrador
cd tools
.\install_windows_service.ps1
```

El servicio se configura con:
- **Nombre**: CatalogadorAPI
- **Puerto**: 8000
- **Inicio**: Automático
- **Logs**: `logs/service_*.log`

### Comandos del Servicio

```powershell
# Iniciar servicio
.\tools\start_service.ps1

# Detener servicio
.\tools\stop_service.ps1

# Verificar estado
nssm status CatalogadorAPI

# Ver logs
Get-Content logs\service_stdout.log -Tail 50
```

### Desinstalar el Servicio

```powershell
.\tools\uninstall_service.ps1
```

---

## 🧪 Testing

```powershell
# Activar entorno virtual
.\.venv\Scripts\Activate.ps1

# Ejecutar todos los tests
python -m pytest -v

# Ejecutar tests específicos
python -m pytest tests/test_trd.py -v

# Con cobertura
python -m pytest --cov=api --cov=engine

# Validar configuración
.\scripts\validate_setup.sh
```

**Estado actual**: ✅ 11/11 tests passing

---

## 📚 Documentación

- **[VSCODE_SETUP.md](VSCODE_SETUP.md)** - Configuración entorno VSCode (400+ líneas)
- **[ARCHITECTURAL_ANALYSIS.md](ARCHITECTURAL_ANALYSIS.md)** - Análisis arquitectónico completo
- **[CONSOLIDATION_PLAN.md](CONSOLIDATION_PLAN.md)** - Plan de consolidación ejecutado
- **[REFACTOR_STATUS.md](REFACTOR_STATUS.md)** - Estado REFACTOR-Ω PHASE 1
- **[SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.md)** - Resumen de soluciones implementadas

---

## 🔐 Seguridad

- API accesible solo en localhost (127.0.0.1)
- Sin exposición externa por defecto
- Logs de auditoría en `logs/`
- Validación de entrada con Pydantic

---

## 🐛 Solución de Problemas

### El servicio no inicia

```powershell
# Verificar logs
Get-Content logs\service_stderr.log

# Verificar Python
python --version  # Debe ser 3.11+

# Verificar dependencias
pip list | Select-String fastapi
```

### La aplicación no conecta al API

1. Verificar que el servicio está ejecutándose:
   ```powershell
   nssm status CatalogadorAPI
   ```

2. Probar endpoint manualmente:
   ```powershell
   curl http://127.0.0.1:8000/health
   ```

3. Revisar logs de la aplicación:
   - Windows: `%LOCALAPPDATA%\CatalogadorEsSalud\logs\`

### Errores de compilación WPF

```powershell
# Limpiar y reconstruir
dotnet clean Catalogador.sln
dotnet restore Catalogador.sln
dotnet build Catalogador.sln -c Release
```

---

## 🤝 Contribución

### Flujo de Trabajo

1. Fork el repositorio
2. Crear rama: `git checkout -b feature/nueva-funcionalidad`
3. Commit cambios: `git commit -m "feat: descripción"`
4. Push: `git push origin feature/nueva-funcionalidad`
5. Crear Pull Request

### Estándares de Código

- **Python**: PEP 8, verificar con `ruff` y `mypy`
- **C#**: Convenciones .NET, nomenclatura PascalCase
- **Commits**: Conventional Commits (feat:, fix:, docs:, etc.)

---

## 📋 Requisitos del Sistema

### Desarrollo
- Windows 10/11 (64-bit)
- Python 3.11 o superior
- .NET 8 SDK
- Visual Studio 2022 o VSCode
- Git 2.30+

### Producción
- Windows 10/11 (64-bit)
- Python 3.11+ (runtime)
- .NET 8 Runtime
- 4GB RAM mínimo
- 500MB espacio en disco

---

## 📄 Licencia

[Especificar licencia]

---

## 👥 Contacto

- **Proyecto**: Catalogador EsSalud
- **Repositorio**: https://github.com/martinosorio302/catalogador
- **Issues**: https://github.com/martinosorio302/catalogador/issues

---

## 📌 Notas Importantes

### Directorios Deprecados

Los siguientes directorios contienen implementaciones **deprecadas** que serán removidas:

- `frontend/` - Frontend Electron/React (reemplazado por WPF)
- `src/` - Frontend Electron alternativo (reemplazado por WPF)
- `electron/` - Proceso principal Electron (ya no necesario)
- `backend/` - Backend .NET (reemplazado por Python FastAPI)
- `pr_bundle/`, `pr_bundle_v2/` - Bundles antiguos

Ver archivos `DEPRECATED.md` en cada directorio para más información.

### Historial Git

Todo el código deprecado se preserva en el historial de Git y puede recuperarse si es necesario:

```bash
git checkout <commit> -- <path>
```

---

**Última actualización**: 2025-11-11  
**Versión**: 1.0.0 (Arquitectura consolidada)

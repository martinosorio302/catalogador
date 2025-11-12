# Catalogador EsSalud - Documentación Completa

## Tabla de Contenidos

- [Visión General](#visión-general)
- [Requisitos del Sistema](#requisitos-del-sistema)
- [Instalación](#instalación)
- [Desarrollo](#desarrollo)
- [Arquitectura](#arquitectura)
- [Construcción](#construcción)
- [Despliegue](#despliegue)
- [Solución de Problemas](#solución-de-problemas)
- [API Reference](#api-reference)

---

## Visión General

Catalogador EsSalud es una aplicación de escritorio Windows para la gestión y clasificación de documentos con:

- **Frontend**: Aplicación WPF .NET 8 (interfaz gráfica nativa de Windows)
- **Backend**: API REST Python FastAPI (servicio Windows)
- **Motor**: TRD (Tabla de Retención Documental) para clasificación automática
- **OCR**: Procesamiento de documentos PDF con extracción de texto
- **Exportación**: Generación de inventarios en formato Excel (XLSX)

### Características Principales

- ✅ Carga y procesamiento de documentos PDF
- ✅ Clasificación automática según TRD de EsSalud
- ✅ Visualización de reglas TRD
- ✅ Exportación de inventarios a Excel
- ✅ Backend como servicio Windows (inicio automático)
- ✅ Instalador profesional (.exe)

---

## Requisitos del Sistema

### Para Usuarios Finales

- **Sistema Operativo**: Windows 10/11 (64-bit)
- **Memoria RAM**: 4 GB mínimo, 8 GB recomendado
- **Espacio en Disco**: 500 MB para aplicación + espacio para documentos
- **Software**:
  - .NET 8 Desktop Runtime
  - Python 3.11 o superior

### Para Desarrolladores

Todo lo anterior, más:

- **IDEs** (opcional):
  - Visual Studio 2022 o superior
  - Visual Studio Code con extensiones recomendadas
- **Herramientas**:
  - Git
  - Inno Setup 6.x (para crear instalador)
  - NSSM (incluido en `tools/`)

---

## Instalación

### Opción A: Instalador (Usuarios Finales)

1. **Descargar** el instalador:
   - `CatalogadorEsSalud_Setup_1.0.0.exe`

2. **Ejecutar** el instalador como Administrador

3. **Seguir** el asistente de instalación:
   - Aceptar licencia MIT
   - Elegir directorio de instalación
   - Seleccionar "Instalar servicio de backend"
   - Crear accesos directos

4. **Iniciar** la aplicación desde:
   - Menú Inicio → Catalogador EsSalud
   - Acceso directo en Escritorio (si se creó)

### Opción B: Desde Código Fuente (Desarrolladores)

1. **Clonar** el repositorio:
```bash
git clone https://github.com/martinosorio302/catalogador.git
cd catalogador
```

2. **Instalar** Python y dependencias:
```powershell
# Crear entorno virtual
python -m venv .venv

# Activar entorno
.\.venv\Scripts\Activate.ps1

# Instalar dependencias
pip install -r requirements.txt -r dev-requirements.txt -e .
```

3. **Compilar** la aplicación WPF:
```powershell
dotnet build Catalogador.sln -c Release
```

4. **Ejecutar** la aplicación:
```powershell
.\Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe
```

---

## Desarrollo

### Estructura del Proyecto

```
Catalogador/
├── api/                          # Backend Python FastAPI
│   ├── main.py                   # Punto de entrada FastAPI
│   ├── routers/                  # Endpoints REST
│   │   ├── health.py             # Health check
│   │   ├── classify.py           # Clasificación de documentos
│   │   ├── files.py              # Gestión de archivos
│   │   └── trd.py                # Información TRD
│   ├── services/                 # Lógica de negocio
│   │   ├── ocr_engine.py         # Procesamiento OCR
│   │   ├── pdf_reader.py         # Lectura de PDFs
│   │   ├── classifier.py         # Motor de clasificación
│   │   └── metadata.py           # Extracción de metadatos
│   └── models/                   # Modelos de datos
│       ├── document.py           # Modelo de documento
│       └── classification.py     # Modelo de clasificación
├── engine/                       # Motor TRD
│   └── trd.py                    # Lógica de clasificación TRD
├── Catalogador.App/              # Frontend WPF .NET 8
│   ├── App.xaml                  # Aplicación principal
│   ├── Views/                    # Interfaces de usuario
│   │   └── MainWindow.xaml       # Ventana principal
│   ├── Services/                 # Servicios
│   │   └── ApiClient.cs          # Cliente HTTP para API
│   ├── Helpers/                  # Utilidades
│   │   └── SimpleLogger.cs       # Sistema de logging
│   └── Models/                   # Modelos de datos
│       └── DocumentModels.cs     # Modelos de documento
├── tools/                        # Scripts de servicio Windows
│   ├── install_windows_service.ps1
│   ├── uninstall_service.ps1
│   ├── start_service.ps1
│   └── stop_service.ps1
├── installer/                    # Configuración InnoSetup
│   └── catalogador_setup.iss     # Script del instalador
├── tests/                        # Tests Python (pytest)
├── scripts/                      # Scripts de utilidad
└── data/                         # Datos de configuración TRD
```

### Configuración de Desarrollo

#### Visual Studio Code

1. **Abrir** el proyecto en VSCode
2. **Instalar** extensiones recomendadas (automático)
3. **Seleccionar** intérprete Python (`.venv`)
4. **Usar** tareas predefinidas:
   - `Ctrl+Shift+P` → "Tasks: Run Task"
   - Opciones: Build Python, Run Tests, Start API, etc.

#### Visual Studio 2022

1. **Abrir** `Catalogador.sln`
2. **Configurar** Python:
   - Tools → Python → Python Environments
   - Add Environment → Existing environment → `.venv`
3. **Build** → Build Solution
4. **Debug** → Start Debugging (F5)

### Flujo de Trabajo

#### Backend (API Python)

```powershell
# Iniciar en modo desarrollo
python -m uvicorn api.main:app --reload --port 8000

# Ejecutar tests
python -m pytest -v

# Linting
ruff check api/ engine/

# Type checking
mypy api/ engine/
```

#### Frontend (WPF)

```powershell
# Compilar en Debug
dotnet build Catalogador.sln -c Debug

# Ejecutar aplicación
.\Catalogador.App\bin\Debug\net8.0-windows\CatalogadorEsSalud.exe

# O desde Visual Studio: F5
```

### Testing

#### Tests Python (pytest)

```powershell
# Todos los tests
python -m pytest -v

# Test específico
python -m pytest tests/test_ocr.py -v

# Con cobertura
python -m pytest --cov=api --cov=engine --cov-report=html
```

#### Tests WPF (Manual)

1. Compilar aplicación en Debug
2. Iniciar backend manualmente
3. Ejecutar aplicación WPF
4. Verificar funcionalidad:
   - Conexión con backend
   - Carga de documentos
   - Clasificación TRD
   - Exportación Excel

---

## Arquitectura

### Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────┐
│                    Usuario Final                        │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│           Catalogador.App (WPF .NET 8)                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Document   │  │  TRD Viewer  │  │   Inventory  │ │
│  │    Upload    │  │              │  │    Export    │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │        ApiClient (HTTP Client)                   │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP REST (127.0.0.1:8000)
┌────────────────────────▼────────────────────────────────┐
│           Python FastAPI Backend (Servicio Windows)     │
│  ┌──────────────────────────────────────────────────┐  │
│  │               Routers (Endpoints)                │  │
│  │  /health  /classify  /files  /trd  /inventory   │  │
│  └────────────────────┬─────────────────────────────┘  │
│                       │                                 │
│  ┌────────────────────▼─────────────────────────────┐  │
│  │               Services (Lógica)                  │  │
│  │  OCR Engine │ PDF Reader │ Classifier │ Metadata│  │
│  └────────────────────┬─────────────────────────────┘  │
│                       │                                 │
│  ┌────────────────────▼─────────────────────────────┐  │
│  │              Models (Datos)                      │  │
│  │  Document │ Classification │ TRDRule             │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│              TRD Engine (Clasificación)                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Reglas TRD EsSalud (JSON)                      │  │
│  │  - Series documentales                           │  │
│  │  - Subseries                                     │  │
│  │  - Códigos                                       │  │
│  │  - Plazos de retención                          │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Flujo de Datos: Clasificación de Documento

1. **Usuario** carga PDF en WPF
2. **WPF** → API: `POST /classify` (archivo PDF)
3. **API** → OCR Engine: Extrae texto del PDF
4. **API** → PDF Reader: Extrae metadatos
5. **API** → Classifier: Analiza contenido
6. **Classifier** → TRD Engine: Busca reglas aplicables
7. **TRD Engine** → Classifier: Devuelve clasificación
8. **Classifier** → API: Resultado de clasificación
9. **API** → WPF: JSON con clasificación
10. **WPF**: Muestra resultado al usuario

### Tecnologías

| Componente | Tecnología | Versión | Propósito |
|------------|-----------|---------|-----------|
| Frontend | WPF .NET | 8.0 | Interfaz gráfica Windows |
| Backend | Python FastAPI | 0.115+ | API REST |
| Servidor Web | uvicorn | 0.32+ | Servidor ASGI |
| OCR | PyMuPDF | 1.25+ | Extracción de texto PDF |
| PDF Processing | pdfplumber | 0.11+ | Análisis de PDFs |
| Excel Export | ClosedXML | 0.104+ | Generación XLSX |
| Servicio Windows | NSSM | 2.24+ | Gestión de servicio |
| Instalador | Inno Setup | 6.x | Empaquetado Windows |

---

## Construcción

### Build Automatizado (Recomendado)

```powershell
# Build completo
.\build.bat

# O con PowerShell
.\scripts\build_all.ps1

# Build + Instalador
.\scripts\build_all.ps1 -BuildInstaller
```

### Build Manual

#### 1. Backend Python

```powershell
# Instalar dependencias
pip install -r requirements.txt -e .

# Verificar instalación
python -c "import api.main; print('OK')"

# Ejecutar tests
python -m pytest -v
```

#### 2. Frontend WPF

```powershell
# Limpiar builds anteriores
dotnet clean Catalogador.sln

# Restaurar dependencias
dotnet restore Catalogador.sln

# Compilar Release
dotnet build Catalogador.sln -c Release

# Resultado: Catalogador.App\bin\Release\net8.0-windows\
```

#### 3. Instalador InnoSetup

**Requisitos previos**:
- Inno Setup 6.x instalado
- WPF compilada en Release

**Pasos**:
```powershell
# Cambiar a directorio installer
cd installer

# Compilar con Inno Setup
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" catalogador_setup.iss

# Resultado: installer\output\CatalogadorEsSalud_Setup_1.0.0.exe
```

**Ver**: `installer/BUILD_INSTRUCTIONS.md` para detalles completos.

---

## Despliegue

### Opción 1: Instalador (.exe)

**Para usuarios finales**:

1. Distribuir `CatalogadorEsSalud_Setup_1.0.0.exe`
2. Usuario ejecuta instalador
3. Instalador:
   - Verifica requisitos (.NET 8, Python 3.11+)
   - Instala aplicación en `C:\Program Files\Catalogador EsSalud\`
   - Configura servicio Windows (opcional)
   - Crea accesos directos

### Opción 2: Servicio Manual

**Para servidores o instalación personalizada**:

```powershell
# 1. Instalar servicio backend
.\tools\install_windows_service.ps1

# 2. Verificar servicio
nssm status CatalogadorAPI

# 3. Ver logs
Get-Content logs\service_*.log -Tail 50

# 4. Gestionar servicio
.\tools\start_service.ps1    # Iniciar
.\tools\stop_service.ps1     # Detener
.\tools\uninstall_service.ps1  # Desinstalar
```

### Opción 3: Ejecución Manual (Desarrollo)

```powershell
# Terminal 1: Backend
python -m uvicorn api.main:app --host 0.0.0.0 --port 8000

# Terminal 2: Frontend
.\Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe
```

### Configuración

#### Puerto del Backend

**Cambiar puerto predeterminado (8000)**:

1. Editar `tools/install_windows_service.ps1`:
```powershell
-Port 8080  # Cambiar de 8000 a 8080
```

2. Editar `Catalogador.App/Services/ApiClient.cs`:
```csharp
private readonly string _baseUrl = "http://127.0.0.1:8080";  // Cambiar puerto
```

#### Logs

**Ubicaciones**:
- **Aplicación WPF**: `%LOCALAPPDATA%\CatalogadorEsSalud\logs\`
- **Servicio Backend**: `[InstallDir]\logs\service_*.log`
- **Backend desarrollo**: Consola

**Nivel de log**:
- Editar `api/main.py`: `logging.basicConfig(level=logging.INFO)`

---

## Solución de Problemas

### Problema: Backend no inicia

**Síntomas**:
- WPF muestra "Desconectado"
- Error "Connection refused"

**Soluciones**:

1. Verificar servicio:
```powershell
nssm status CatalogadorAPI
# Si stopped: nssm start CatalogadorAPI
```

2. Verificar puerto:
```powershell
netstat -ano | findstr :8000
# Si ocupado, cambiar puerto
```

3. Verificar logs:
```powershell
Get-Content logs\service_*.log -Tail 100
```

4. Iniciar manualmente para debug:
```powershell
python -m uvicorn api.main:app --reload
```

### Problema: Error al compilar WPF

**Síntomas**:
- Error "backend/Program.cs"
- Proyectos no encontrados

**Soluciones**:

1. Actualizar repositorio:
```powershell
git pull origin copilot/fix-integration-issues-vscode
```

2. Verificar que `backend/` no existe:
```powershell
ls backend  # Debe dar error "not found"
```

3. Limpiar y rebuild:
```powershell
dotnet clean Catalogador.sln
dotnet restore Catalogador.sln
dotnet build Catalogador.sln -c Release
```

### Problema: Tests fallan

**Síntomas**:
- `pytest` falla en tests de OCR o clasificación

**Soluciones**:

1. Reinstalar dependencias:
```powershell
pip install -r requirements.txt --force-reinstall
```

2. Verificar datos TRD:
```powershell
python -c "import json; json.load(open('data/essalud_pcd_anexo02.full.json'))"
```

3. Ejecutar test específico con verbose:
```powershell
python -m pytest tests/test_classifier.py -v -s
```

### Problema: Instalador falla

**Síntomas**:
- Inno Setup reporta errores
- Archivos no encontrados

**Soluciones**:

1. Compilar WPF primero:
```powershell
dotnet build Catalogador.sln -c Release
```

2. Verificar rutas en `catalogador_setup.iss`:
   - Todas las rutas deben ser relativas al .iss
   - Verificar que archivos existen

3. Ver log detallado de Inno Setup:
   - Abrir `catalogador_setup.iss` en Inno Setup
   - Compile → View Output

### Problema: Servicio no auto-inicia

**Síntomas**:
- Después de reiniciar Windows, backend no funciona

**Soluciones**:

1. Verificar configuración:
```powershell
nssm get CatalogadorAPI Start
# Debe ser: SERVICE_AUTO_START
```

2. Reconfigurar si es necesario:
```powershell
nssm set CatalogadorAPI Start SERVICE_AUTO_START
```

3. Verificar que Python está en PATH del sistema (no solo usuario)

---

## API Reference

### Base URL

```
http://127.0.0.1:8000
```

### Endpoints

#### Health Check

```http
GET /health
```

**Respuesta**:
```json
{
  "status": "ok",
  "version": "1.0.0"
}
```

#### Clasificar Documento

```http
POST /classify
Content-Type: multipart/form-data

file: <PDF file>
```

**Respuesta**:
```json
{
  "filename": "documento.pdf",
  "classification": {
    "code": "02.01.01",
    "series": "Actas de Sesión de Junta Directiva",
    "subseries": "Actas originales",
    "retention_period": "10 años"
  },
  "confidence": 0.95,
  "metadata": {
    "pages": 5,
    "size_kb": 1024
  }
}
```

#### Obtener Información TRD

```http
GET /trd
```

**Respuesta**:
```json
{
  "total_rules": 150,
  "series": [
    {
      "code": "02.01",
      "name": "Actas",
      "subseries": [...]
    }
  ]
}
```

#### Exportar Inventario

```http
POST /inventory/export
Content-Type: application/json

{
  "documents": [...]
}
```

**Respuesta**: Archivo XLSX (binary)

### Códigos de Estado

| Código | Significado |
|--------|-------------|
| 200 | OK - Solicitud exitosa |
| 400 | Bad Request - Datos inválidos |
| 404 | Not Found - Recurso no encontrado |
| 500 | Internal Server Error - Error del servidor |

---

## Recursos Adicionales

### Documentación

- [QUICK_START.md](QUICK_START.md) - Inicio rápido
- [VSCODE_SETUP.md](VSCODE_SETUP.md) - Configuración VSCode
- [ARCHITECTURAL_ANALYSIS.md](ARCHITECTURAL_ANALYSIS.md) - Análisis arquitectónico
- [CHANGELOG.md](CHANGELOG.md) - Historial de cambios
- [installer/BUILD_INSTRUCTIONS.md](installer/BUILD_INSTRUCTIONS.md) - Instrucciones instalador

### Soporte

- **Repositorio**: https://github.com/martinosorio302/catalogador
- **Issues**: https://github.com/martinosorio302/catalogador/issues
- **Licencia**: MIT (ver [LICENSE](LICENSE))

---

**Última actualización**: 2025-11-11  
**Versión**: 1.0.0  
**Autor**: EsSalud / REFACTOR-Ω CATALOGADOR ENGINE

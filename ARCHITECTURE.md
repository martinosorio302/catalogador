# Arquitectura del Sistema Catalogador EsSalud

## 📋 Tabla de Contenidos
1. [Visión General](#visión-general)
2. [Arquitectura de Componentes](#arquitectura-de-componentes)
3. [Backend API](#backend-api)
4. [Frontend Desktop](#frontend-desktop)
5. [Motor de Clasificación](#motor-de-clasificación)
6. [Flujo de Datos](#flujo-de-datos)
7. [Deployment](#deployment)
8. [Testing](#testing)
9. [Mantenimiento](#mantenimiento)

---

## 🎯 Visión General

### Propósito
Sistema de gestión documental para clasificación automática de documentos PDF según la Tabla de Retención Documental (TRD) de EsSalud.

### Stack Tecnológico
```
Backend:    FastAPI 0.121.0 + Uvicorn 0.38.0 (Python 3.12)
Frontend:   .NET 8 WPF (Windows Presentation Foundation)
OCR:        PyMuPDF 1.24.14 (fitz)
Export:     openpyxl 3.1.5
Testing:    pytest 9.0.1
Linting:    Ruff
Service:    NSSM (Non-Sucking Service Manager)
CI/CD:      GitHub Actions
```

### Principios de Diseño
- **Separación de Responsabilidades**: Backend API independiente, Frontend consumidor
- **Modularidad**: Engine de clasificación desacoplado de la API
- **Escalabilidad**: Arquitectura preparada para múltiples clientes
- **Mantenibilidad**: Código moderno (PEP 604/585), type hints completos
- **Testabilidad**: 100% cobertura de endpoints críticos

---

## 🏗️ Arquitectura de Componentes

```
┌─────────────────────────────────────────────────────────────────┐
│                     CATALOGADOR ESSALUD                          │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐         HTTP/REST          ┌──────────────────┐
│                  │ ◄─────────────────────────► │                  │
│  Frontend WPF    │    127.0.0.1:8000          │   Backend API    │
│  (.NET 8)        │                             │   (FastAPI)      │
│                  │                             │                  │
└──────────────────┘                             └────────┬─────────┘
                                                          │
        User Interface                                    │ calls
        ├── Upload PDF                                    ▼
        ├── View TRD Info                    ┌────────────────────────┐
        └── Export Excel                     │  Engine de             │
                                             │  Clasificación TRD     │
                                             │  (engine/trd.py)       │
                                             └────────────────────────┘
                                                          │
                                                          │ reads
                                                          ▼
                                             ┌────────────────────────┐
                                             │  TRD Data              │
                                             │  (engine/data/trd.json)│
                                             └────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      DEPLOYMENT (Windows)                        │
├─────────────────────────────────────────────────────────────────┤
│  Development:  C:\Users\USER\Desktop\Catalogador\               │
│  Production:   C:\ProgramData\Catalogador\python_api\           │
│  Service:      Catalogador-PythonAPI (NSSM)                     │
│  Logs:         C:\ProgramData\Catalogador\python_api\logs\      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔌 Backend API

### Estructura de Directorios
```
api/
├── __init__.py
├── main.py                 # FastAPI app + lifespan handlers
├── models/
│   ├── __init__.py
│   └── classification.py   # Pydantic models
├── routers/
│   ├── __init__.py
│   ├── health.py          # GET /health
│   ├── files.py           # POST /upload, GET /documents
│   ├── classify.py        # POST /classify, GET /trd-info
│   └── admin.py           # POST /reload, GET /export/inventory
└── services/
    ├── __init__.py
    ├── classifier.py      # Business logic
    └── metadata.py        # Metadata extraction
```

### Endpoints Disponibles

#### 1. Health Check
```http
GET /health
Response: {"ok": true}
Status: 200 OK
```

#### 2. Upload Document
```http
POST /upload
Content-Type: multipart/form-data
Body: file (PDF)

Response: {
  "saved": "/path/to/file.pdf",
  "filename": "document.pdf",
  "size_bytes": 1234567,
  "classification": {
    "extracted": true,
    "text_length": 5000,
    "code": "CODI/01",
    "tituloSerie": "ACTAS DE SESIONES",
    "plazoConservacionAnios": 30,
    "temporalidad": "Permanente",
    "destino": "Conservación Permanente",
    "descripcionInventario": "Documentación oficial..."
  }
}
```

**Flujo interno**:
1. Validar tamaño máximo (20MB por defecto)
2. Sanitizar nombre de archivo
3. Guardar en `data/uploads/`
4. Extraer texto con PyMuPDF (si es PDF)
5. Clasificar con `engine.trd.aplicar_reglas_trd()`
6. Retornar resultado con clasificación

#### 3. Classify Document
```http
POST /classify
Content-Type: application/json
Body: {
  "asuntoUnidad": "CONSEJO DIRECTIVO",
  "titulo": "Actas de sesiones",
  "productor": null,
  "serie": "Actas"
}

Response: {
  "code": "CODI/01",
  "tituloSerie": "ACTAS DE SESIONES",
  "plazoConservacionAnios": 30,
  "temporalidad": "Permanente",
  "destino": "Conservación Permanente",
  "descripcionInventario": "..."
}
```

#### 4. TRD Information
```http
GET /trd-info

Response: {
  "total_entries": 150,
  "total_codes": 145,
  "sample_entries": [
    {
      "code": "CODI/01",
      "titulo": "ACTAS DE SESIONES",
      "valor": "Permanente",
      "ag": 2,
      "ap": 0,
      "oaa": 28,
      "total": 30,
      "asunto": "CONSEJO DIRECTIVO"
    },
    ...
  ],
  "index_tokens": 25,
  "inventory_descriptions": 145
}
```

#### 5. Export Inventory
```http
GET /export/inventory

Response: Binary (Excel .xlsx)
Headers:
  Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
  Content-Disposition: attachment; filename=inventario_trd.xlsx

Excel Structure:
  Columns: Código | Título Serie | Asunto | Plazo (años) | 
           Temporalidad | Destino | AG | AP | OAA | Total
  Headers: Blue background (#366092), bold, white text
  Data: All TRD_TABLA entries
```

#### 6. Reload TRD Data
```http
POST /reload
Headers: X-Admin-Token: <token>

Response: {
  "ok": true,
  "counts": {
    "trd_tabla": 150,
    "indice_tokens": 25,
    "inventario_descripcion": 145
  }
}
```

### Lifespan Management
```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Catalogador API starting up")
    yield
    # Shutdown (if needed)
    logger.info("Catalogador API shutting down")
```

**Ventajas**:
- Reemplaza `@app.on_event` deprecated
- Manejo explícito de recursos
- Mejor control de startup/shutdown

---

## 🖥️ Frontend Desktop

### Estructura
```
Catalogador.App/
├── App.xaml              # Application entry point
├── App.xaml.cs
├── MainWindow.xaml       # Main UI definition
├── MainWindow.xaml.cs
├── Catalogador.App.csproj
├── Helpers/
│   └── SimpleLogger.cs   # Logging utility
├── Models/              
├── Services/
│   └── ApiClient.cs      # HTTP client singleton
└── Views/
    └── MainWindow.xaml   # Main window view
```

### ApiClient Implementation

**Patrón**: Singleton thread-safe

```csharp
public class ApiClient
{
    private static ApiClient? _instance;
    private static readonly object _lock = new object();
    
    public static ApiClient Instance
    {
        get
        {
            if (_instance == null)
            {
                lock (_lock)
                {
                    if (_instance == null)
                    {
                        _instance = new ApiClient();
                    }
                }
            }
            return _instance;
        }
    }
}
```

**Features**:
- Auto-detección de backend URL
- Timeout: 5 minutos (para PDFs grandes)
- Retry logic en detección de backend
- Logging integrado con SimpleLogger

### Métodos Principales

#### 1. CheckHealthAsync()
```csharp
public async Task<bool> CheckHealthAsync()
{
    var response = await _httpClient.GetAsync("/health");
    if (response.IsSuccessStatusCode)
    {
        var content = await response.Content.ReadAsStringAsync();
        var healthData = JsonSerializer.Deserialize<JsonElement>(content);
        return healthData.TryGetProperty("ok", out var okValue) 
               && okValue.GetBoolean();
    }
    return false;
}
```

#### 2. UploadFileAsync()
```csharp
public async Task<string> UploadFileAsync(string filePath)
{
    using var content = new MultipartFormDataContent();
    var fileBytes = await File.ReadAllBytesAsync(filePath);
    var fileContent = new ByteArrayContent(fileBytes);
    fileContent.Headers.ContentType = 
        new MediaTypeHeaderValue("application/pdf");
    
    content.Add(fileContent, "file", Path.GetFileName(filePath));
    
    var response = await _httpClient.PostAsync("/upload", content);
    // ... handle response
}
```

### UI Components

**MainWindow.xaml** estructura:
```xml
<Window>
  <Grid>
    <!-- Status Bar -->
    <StackPanel Orientation="Horizontal">
      <Ellipse Name="statusIndicator" /> <!-- Green/Red indicator -->
      <TextBlock Name="txtApiStatus" />
    </StackPanel>
    
    <!-- Upload Section -->
    <Button Name="btnSelectFile" Click="BtnSelectFile_Click" />
    <TextBlock Name="txtSelectedFile" />
    <Button Name="btnUpload" Click="BtnUpload_Click" />
    
    <!-- Results Display -->
    <TextBox Name="txtResults" IsReadOnly="True" />
    
    <!-- TRD Info Section -->
    <Button Name="btnLoadTrd" Click="BtnLoadTrd_Click" />
    <TextBox Name="txtTrdInfo" />
    
    <!-- Export Section -->
    <Button Name="btnExport" Click="BtnExport_Click" />
    <TextBlock Name="txtExportStatus" />
  </Grid>
</Window>
```

---

## ⚙️ Motor de Clasificación

### engine/trd.py - Algoritmo de Clasificación

#### 1. Normalización de Texto
```python
def normaliza(s: str | None) -> str:
    """Normaliza texto: elimina acentos, convierte a mayúsculas"""
    if not s:
        return ""
    n = unicodedata.normalize("NFD", s)
    n = "".join(ch for ch in n if unicodedata.category(ch) != "Mn")
    return n.upper()
```

#### 2. Clasificación por Tokens
```python
def clasificar_por_tokens(
    asunto_unidad: str | None,
    titulo_doc: str | None,
    productor: str | None
) -> str | None:
    """Clasifica documento basándose en tokens indexados"""
    txt = texto_indice(asunto_unidad, titulo_doc, productor)
    for r in INDICE_TOKENS:
        if tokens_incluidos(txt, r.get("tokens", [])):
            codes = r.get("codes") or []
            return codes[0] if codes else None
    return None
```

#### 3. Búsqueda por Asunto y Título
```python
def buscar_trd_por_asunto_titulo(
    asunto: str,
    serie_sugerida: str | None = None
) -> dict[str, Any] | None:
    """Busca entrada TRD que coincida con asunto Y título"""
    a = normaliza(asunto or "")
    s = normaliza(serie_sugerida or "")
    for x in TRD_TABLA:
        asunto_match = normaliza(x.get("asunto", "")) in a
        titulo_match = normaliza(x.get("titulo", "")) in s
        if asunto_match and titulo_match:
            return x
    return None
```

#### 4. Aplicación de Reglas Completas
```python
def aplicar_reglas_trd(input_obj: dict[str, str | None]) -> dict[str, Any]:
    """
    Algoritmo principal de clasificación:
    1. Intenta búsqueda por asunto + serie
    2. Si falla, clasifica por tokens
    3. Si falla, retorna valores por defecto
    """
    # Paso 1: Búsqueda por asunto
    por_asunto = None
    if input_obj.get("serie") and input_obj.get("asuntoUnidad"):
        por_asunto = buscar_trd_por_asunto_titulo(...)
    
    # Paso 2: Clasificación por tokens
    code_tok = clasificar_por_tokens(...)
    
    # Paso 3: Seleccionar entrada
    entry = por_asunto or (buscar_trd_por_codigo(code_tok) if code_tok else None)
    
    # Paso 4: Calcular destino y temporalidad
    if entry:
        es_permanente = entry.get("valor") == "Permanente"
        temporalidad = "Permanente" if es_permanente else "Temporal"
        destino = "Conservación Permanente" if es_permanente else "Eliminación"
        
        # Regla especial: transferencia al archivo central
        if temporalidad == "Temporal" and entry.get("oaa", 0) >= 5:
            destino = "Transferencia al Archivo Central"
        
        return {...}
    
    # Paso 5: Valores por defecto (fallback)
    return {
        "code": None,
        "tituloSerie": "Correspondencia",
        "plazoConservacionAnios": 8,
        "temporalidad": "Temporal",
        "destino": "Eliminación"
    }
```

### Estructura de Datos TRD

#### TRD_TABLA Entry
```python
{
    "code": "CODI/01",                    # Código único
    "titulo": "ACTAS DE SESIONES",        # Título de la serie
    "valor": "Permanente",                # "Permanente" o "Temporal"
    "ag": 2,                              # Años en Archivo de Gestión
    "ap": 0,                              # Años en Archivo Periférico
    "oaa": 28,                            # Años en Oficina Administradora
    "total": 30,                          # Total años de retención
    "asunto": "CONSEJO DIRECTIVO"         # Unidad/Asunto
}
```

#### INDICE_TOKENS Entry
```python
{
    "tokens": ["ACTA", "SESION", "DIRECTORIO"],
    "codes": ["CODI/01"]
}
```

#### INVENTARIO_DESCRIPCION
```python
{
    "CODI/01": "Documentación oficial de actas de sesiones..."
}
```

### Carga Dinámica de Datos

```python
def reload_trd_data() -> dict:
    """
    Recarga datos TRD desde engine/data/trd.json
    Permite actualizar reglas sin reiniciar la aplicación
    """
    global _LOADED, TRD_TABLA, INVENTARIO_DESCRIPCION, INDICE_TOKENS
    
    # 1. Leer archivo JSON
    with _DATA_FILE.open("r", encoding="utf-8") as fh:
        _LOADED = json.load(fh)
    
    # 2. Actualizar estructuras globales
    TRD_TABLA = _get_list("TRD_TABLA", FALLBACK_TRD_TABLA)
    INVENTARIO_DESCRIPCION = _get_dict("INVENTARIO_DESCRIPCION", {})
    INDICE_TOKENS = _get_list("INDICE_TOKENS", [])
    
    # 3. Validar schema
    errors = []
    for i, entry in enumerate(TRD_TABLA):
        if "code" not in entry:
            errors.append(f"entry[{i}].code missing")
    
    # 4. Retornar resumen
    return {
        "loaded": True if not errors else False,
        "counts": {
            "trd_tabla": len(TRD_TABLA),
            "indice_tokens": len(INDICE_TOKENS),
            "inventario_descripcion": len(INVENTARIO_DESCRIPCION)
        },
        "errors": "; ".join(errors) if errors else None
    }
```

---

## 🔄 Flujo de Datos

### Flujo Completo: Upload + Clasificación

```
┌─────────────┐
│   Usuario   │
│ Selecciona  │
│    PDF      │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────────┐
│ WPF: BtnUpload_Click                 │
│ - Llama ApiClient.UploadFileAsync()  │
└──────┬───────────────────────────────┘
       │ HTTP POST /upload (multipart)
       ▼
┌──────────────────────────────────────┐
│ Backend: files.py::upload()          │
│ 1. Validar tamaño (< 20MB)           │
│ 2. Sanitizar filename                │
│ 3. Guardar en data/uploads/          │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ extract_text_from_pdf()              │
│ - PyMuPDF (fitz)                     │
│ - Extrae todo el texto del PDF       │
└──────┬───────────────────────────────┘
       │ extracted_text (string)
       ▼
┌──────────────────────────────────────┐
│ engine.trd.aplicar_reglas_trd()      │
│ 1. Normalizar texto                  │
│ 2. Buscar por asunto + serie         │
│ 3. Clasificar por tokens             │
│ 4. Calcular destino y temporalidad   │
└──────┬───────────────────────────────┘
       │ classification_result (dict)
       ▼
┌──────────────────────────────────────┐
│ Agregar descripción de inventario    │
│ - INVENTARIO_DESCRIPCION[code]       │
└──────┬───────────────────────────────┘
       │ JSON Response
       ▼
┌──────────────────────────────────────┐
│ WPF: Parsear respuesta JSON          │
│ - Mostrar en txtResults              │
│ - Código, Título, Plazo, Destino     │
└──────────────────────────────────────┘
```

### Flujo: Export Inventory

```
┌─────────────┐
│   Usuario   │
│ Click       │
│ "Exportar"  │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────────┐
│ WPF: BtnExport_Click                 │
│ - Llama ApiClient.ExportInventoryAsync()
└──────┬───────────────────────────────┘
       │ HTTP GET /export/inventory
       ▼
┌──────────────────────────────────────┐
│ Backend: admin.py::export_inventory() │
│ 1. Crear workbook con openpyxl       │
│ 2. Agregar headers estilizados       │
│ 3. Iterar sobre TRD_TABLA             │
│ 4. Ajustar anchos de columna         │
└──────┬───────────────────────────────┘
       │ BytesIO (Excel binary)
       ▼
┌──────────────────────────────────────┐
│ StreamingResponse                     │
│ - media_type: .xlsx                   │
│ - Content-Disposition: attachment     │
└──────┬───────────────────────────────┘
       │ Binary data
       ▼
┌──────────────────────────────────────┐
│ WPF: Recibir byte array              │
│ - Mostrar SaveFileDialog              │
│ - Guardar como inventario_YYMMDD.xlsx│
└──────────────────────────────────────┘
```

---

## 🚀 Deployment

### Entornos

#### Desarrollo
```
Ubicación: C:\Users\USER\Desktop\Catalogador\
Venv:      .venv\
Ejecución: python -m uvicorn api.main:app --reload
Puerto:    8000 (o 8001 si 8000 ocupado)
Logs:      Console output
```

#### Producción
```
Ubicación: C:\ProgramData\Catalogador\python_api\
Venv:      venv\
Servicio:  Catalogador-PythonAPI (NSSM)
Puerto:    8000
Logs:      C:\ProgramData\Catalogador\python_api\logs\uvicorn.log
Auto-start: Yes (Windows service)
```

### Scripts de Deployment

#### 1. update_service.ps1 (Requiere Admin)

**Propósito**: Actualizar servicio Windows con código nuevo

**Pasos**:
1. Verificar privilegios de administrador
2. Detener servicio `Catalogador-PythonAPI`
3. Copiar `api/` de desarrollo a producción
4. Copiar `engine/` de desarrollo a producción
5. Verificar dependencias (PyMuPDF, openpyxl)
6. Instalar dependencias faltantes
7. Iniciar servicio
8. Validar endpoints (/health, /trd-info, /docs)

**Uso**:
```powershell
# Como Administrador
cd C:\Users\USER\Desktop\Catalogador\tools
.\update_service.ps1
```

#### 2. run_dev_mode.ps1 (Sin Admin)

**Propósito**: Ejecutar backend en modo desarrollo sin servicio Windows

**Pasos**:
1. Verificar venv de desarrollo
2. Verificar dependencias (PyMuPDF, openpyxl)
3. Detectar si puerto 8000 está ocupado
4. Ofrecer puerto alternativo (8001) si es necesario
5. Ejecutar uvicorn en modo reload

**Uso**:
```powershell
# Terminal normal
cd C:\Users\USER\Desktop\Catalogador\tools
.\run_dev_mode.ps1
```

### NSSM Configuration

```batch
Service Name:        Catalogador-PythonAPI
Application:         C:\ProgramData\Catalogador\python_api\venv\Scripts\python.exe
Arguments:           -m uvicorn api.main:app --host 127.0.0.1 --port 8000
Working Directory:   C:\ProgramData\Catalogador\python_api
Stdout:              C:\ProgramData\Catalogador\python_api\logs\uvicorn.log
Stderr:              C:\ProgramData\Catalogador\python_api\logs\uvicorn.log
Rotate Bytes:        10485760 (10MB)
Start Type:          Automatic
Priority:            NORMAL_PRIORITY_CLASS
```

### Sincronización Desarrollo → Producción

**Archivos a copiar**:
- `api/` completo
- `engine/` completo
- `requirements.txt` (si cambió)

**No copiar**:
- `.venv/` (usar venv de producción)
- `tests/` (no necesario en producción)
- `.git/` (control de versiones)
- `__pycache__/` (regenerable)

**Comando manual**:
```powershell
robocopy api C:\ProgramData\Catalogador\python_api\api /E /XO
robocopy engine C:\ProgramData\Catalogador\python_api\engine /E /XO
```

---

## 🧪 Testing

### Test Suite Actual

#### 1. test_api_endpoints.py
```python
def test_health(client):
    """Verifica endpoint /health"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"ok": True}

def test_classify_basic(client):
    """Verifica clasificación básica"""
    payload = {
        "asuntoUnidad": "CONSEJO DIRECTIVO",
        "titulo": "Actas de sesiones"
    }
    response = client.post("/classify", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "code" in data
    assert "tituloSerie" in data
```

#### 2. test_trd.py
```python
class TestTRD:
    def test_fallback(self):
        """Verifica fallback cuando no hay match"""
        result = trd.aplicar_reglas_trd({"titulo": "ZZZZZ"})
        assert result["code"] is None
        assert result["temporalidad"] == "Temporal"
    
    def test_sample_match(self):
        """Verifica clasificación con match conocido"""
        result = trd.aplicar_reglas_trd({
            "asuntoUnidad": "CONSEJO DIRECTIVO",
            "serie": "ACTAS"
        })
        assert result["code"] == "CODI/01"
```

#### 3. test_upload_sanitization.py
```python
def test_upload_sanitizes_and_limits(client, tmp_path):
    """Verifica sanitización de nombres y límite de tamaño"""
    # Test path traversal prevention
    # Test file size limit
```

#### 4. test_reload_auth.py
```python
def test_reload_requires_token(client, monkeypatch):
    """Verifica autenticación en endpoint /reload"""
    monkeypatch.setenv("ADMIN_RELOAD_TOKEN", "secret123")
    response = client.post("/reload")
    assert response.status_code == 403
```

### Coverage Report

```
Endpoint             Tests    Coverage
---------------------+--------+---------
GET /health          ✅       100%
POST /classify       ✅       100%
POST /upload         ✅       100%
POST /reload         ✅       100%
GET /trd-info        ⏳       0% (new)
GET /export/inventory ⏳      0% (new)

Engine Functions     Tests    Coverage
---------------------+--------+---------
normaliza()          ✅       100%
clasificar_por_tokens() ✅    100%
aplicar_reglas_trd() ✅       100%
buscar_trd_por_codigo() ✅    100%
reload_trd_data()    ⏳       0% (admin)
```

### Ejecutar Tests

```powershell
# Todos los tests
python -m pytest tests\ -v

# Tests específicos
python -m pytest tests\test_api_endpoints.py -v

# Con cobertura
python -m pytest tests\ --cov=api --cov=engine --cov-report=html

# Solo tests rápidos
python -m pytest tests\ -m "not slow"
```

### Tests Pendientes (Recomendados)

#### 1. test_trd_info_endpoint.py
```python
def test_trd_info_returns_statistics(client):
    """Verifica endpoint GET /trd-info"""
    response = client.get("/trd-info")
    assert response.status_code == 200
    data = response.json()
    assert "total_entries" in data
    assert "total_codes" in data
    assert "sample_entries" in data
    assert isinstance(data["sample_entries"], list)
```

#### 2. test_export_inventory.py
```python
def test_export_generates_excel(client):
    """Verifica exportación a Excel"""
    response = client.get("/export/inventory")
    assert response.status_code == 200
    assert "xlsx" in response.headers["content-type"]
    assert len(response.content) > 0
```

#### 3. test_upload_classification_integration.py
```python
def test_upload_pdf_with_classification(client, sample_pdf):
    """Test integración completa: upload + OCR + clasificación"""
    with open(sample_pdf, "rb") as f:
        response = client.post(
            "/upload",
            files={"file": ("test.pdf", f, "application/pdf")}
        )
    assert response.status_code == 200
    data = response.json()
    assert "classification" in data
    assert data["classification"]["extracted"] is True
```

---

## 🔧 Mantenimiento

### Logs

#### Backend Logs
```
Ubicación: C:\ProgramData\Catalogador\python_api\logs\uvicorn.log
Formato:   [timestamp] [level] [module]: message
Rotación:  10MB automático (NSSM)
Niveles:   INFO, WARNING, ERROR

Ejemplos:
2025-11-14 19:45:23 INFO catalogador.files: File uploaded: document.pdf
2025-11-14 19:45:24 INFO catalogador.files: Classification: CODI/01
2025-11-14 19:45:30 ERROR catalogador.admin: Export failed: openpyxl not installed
```

#### Ver Logs en Tiempo Real
```powershell
# PowerShell
Get-Content C:\ProgramData\Catalogador\python_api\logs\uvicorn.log -Tail 50 -Wait

# CMD
tail -f C:\ProgramData\Catalogador\python_api\logs\uvicorn.log
```

### Monitoreo del Servicio

#### Verificar Estado
```powershell
Get-Service -Name "Catalogador-PythonAPI"

Status   Name                    DisplayName
------   ----                    -----------
Running  Catalogador-PythonAPI   Catalogador-PythonAPI
```

#### Reiniciar Servicio
```powershell
# Detener
net stop Catalogador-PythonAPI

# Iniciar
net start Catalogador-PythonAPI

# Reiniciar
Restart-Service -Name "Catalogador-PythonAPI"
```

#### Health Check Automático
```powershell
# Script de monitoreo (agregar a Task Scheduler)
$health = Invoke-WebRequest -Uri "http://127.0.0.1:8000/health" -UseBasicParsing
if ($health.StatusCode -ne 200) {
    Restart-Service -Name "Catalogador-PythonAPI"
    Send-MailMessage -To "admin@essalud.gob.pe" -Subject "Servicio reiniciado"
}
```

### Actualización de Dependencias

#### Verificar Versiones Actuales
```powershell
.venv\Scripts\python.exe -m pip list
```

#### Actualizar Dependencias
```powershell
# Actualizar requirements.txt
.venv\Scripts\python.exe -m pip install --upgrade -r requirements.txt

# Congelar nuevas versiones
.venv\Scripts\python.exe -m pip freeze > requirements.txt
```

#### Dependencias Críticas
```
fastapi>=0.121.0       # API framework
uvicorn>=0.38.0        # ASGI server
PyMuPDF>=1.24.14       # OCR (fitz)
openpyxl>=3.1.5        # Excel export
pydantic>=2.12.4       # Data validation
```

### Backup y Restore

#### Archivos a Respaldar
```
1. engine/data/trd.json              # Reglas TRD
2. data/uploads/                     # PDFs subidos
3. C:\ProgramData\Catalogador\       # Instalación producción
4. requirements.txt                  # Dependencias
5. api/ y engine/                    # Código fuente
```

#### Script de Backup
```powershell
$backupDir = "C:\Backups\Catalogador\$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupDir

# Código fuente
robocopy C:\Users\USER\Desktop\Catalogador $backupDir\source /E /XD .venv __pycache__ .git

# Datos TRD
Copy-Item C:\Users\USER\Desktop\Catalogador\engine\data\trd.json $backupDir\

# Producción
robocopy C:\ProgramData\Catalogador $backupDir\production /E
```

### Troubleshooting Común

#### Problema 1: Servicio no inicia
```
Síntomas: net start falla, logs muestran import errors
Solución:
1. Verificar venv: C:\ProgramData\Catalogador\python_api\venv\
2. Reinstalar dependencias:
   venv\Scripts\python.exe -m pip install -r requirements.txt
3. Verificar permisos en C:\ProgramData\Catalogador\
```

#### Problema 2: Endpoint 404 Not Found
```
Síntomas: Cliente recibe 404 en endpoint nuevo
Solución:
1. Verificar que api/ esté actualizado en C:\ProgramData\
2. Ejecutar update_service.ps1 como Admin
3. Reiniciar servicio
4. Verificar logs: Get-Content ...\ logs\uvicorn.log -Tail 50
```

#### Problema 3: PDF no se clasifica
```
Síntomas: Upload exitoso pero classification.extracted = false
Solución:
1. Verificar PyMuPDF instalado: python -c "import fitz"
2. Verificar PDF válido (no corrupto)
3. Revisar logs para errores de extracción
4. Probar con PDF diferente
```

#### Problema 4: Excel export falla
```
Síntomas: GET /export/inventory retorna 501 o 500
Solución:
1. Verificar openpyxl instalado: python -c "import openpyxl"
2. Instalar si falta: pip install openpyxl==3.1.5
3. Verificar permisos de escritura
4. Revisar TRD_TABLA no vacía
```

### Performance Tuning

#### Configuración Uvicorn
```python
# Para producción alta carga
uvicorn api.main:app --host 127.0.0.1 --port 8000 \
    --workers 4 \
    --log-level info \
    --access-log \
    --timeout-keep-alive 30
```

#### Limitar Tamaño de Upload
```python
# api/routers/files.py
MAX_UPLOAD_BYTES = int(os.getenv("MAX_UPLOAD_BYTES") or 50000000)  # 50MB
```

#### Cache de Clasificaciones
```python
# Implementar cache LRU para clasificaciones frecuentes
from functools import lru_cache

@lru_cache(maxsize=1000)
def aplicar_reglas_trd_cached(input_tuple):
    input_obj = dict(input_tuple)
    return aplicar_reglas_trd(input_obj)
```

---

## 📚 Referencias

### Documentación Externa
- FastAPI: https://fastapi.tiangolo.com/
- Pydantic: https://docs.pydantic.dev/
- PyMuPDF: https://pymupdf.readthedocs.io/
- openpyxl: https://openpyxl.readthedocs.io/
- NSSM: https://nssm.cc/

### Documentación Interna
- API Docs (Swagger): http://127.0.0.1:8000/docs
- ReDoc: http://127.0.0.1:8000/redoc
- README.md: Guía de inicio rápido
- CHANGELOG.md: Historial de cambios

### Contacto y Soporte
- Repositorio: github.com/martinosorio302/catalogador
- Branch principal: hardening/autofix
- Issues: github.com/martinosorio302/catalogador/issues

---

**Versión**: 1.0.0  
**Última actualización**: 2025-11-14  
**Autor**: Equipo Catalogador EsSalud  
**Estado**: Producción ✅

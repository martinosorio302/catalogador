# API Reference - Catalogador EsSalud

## Overview

The Catalogador EsSalud API provides endpoints for document classification, TRD (Tabla de Retención Documental) management, and inventory export. All endpoints return JSON responses unless otherwise specified.

**Base URL**: `http://127.0.0.1:8000`

**API Documentation**:
- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`

---

## Endpoints

### Health Check

#### `GET /health`

Check API health and status.

**Response**: `200 OK`
```json
{
  "ok": true,
  "status": "healthy"
}
```

**Example**:
```bash
curl http://127.0.0.1:8000/health
```

---

### Document Upload

#### `POST /upload`

Upload a PDF document for automatic classification.

**Request**:
- Method: `POST`
- Content-Type: `multipart/form-data`
- Body:
  - `file`: PDF file (max 20MB)

**Response**: `200 OK`
```json
{
  "ok": true,
  "path": "data/uploads/documento.pdf",
  "size": 245678,
  "extracted": true,
  "text_length": 1234,
  "classification": {
    "code": "CODI/01",
    "tituloSerie": "ACTAS DE SESIONES",
    "plazoConservacionAnios": 30,
    "temporalidad": "Permanente",
    "destino": "Conservación Permanente",
    "descripcionInventario": "Documentos del Consejo Directivo"
  }
}
```

**Error Responses**:
- `413 Payload Too Large`: File exceeds 20MB
- `500 Internal Server Error`: Processing failed

**Example**:
```bash
curl -X POST http://127.0.0.1:8000/upload \
  -F "file=@documento.pdf"
```

**Features**:
- Automatic text extraction using PyMuPDF
- TRD rule-based classification
- Path traversal protection
- File size validation

---

### Document Classification

#### `POST /classify`

Classify a document using TRD rules based on metadata.

**Request**:
- Method: `POST`
- Content-Type: `application/json`
- Body:
```json
{
  "asuntoUnidad": "CONSEJO DIRECTIVO",
  "titulo": "Actas de sesiones",
  "serie": "Actas",
  "productor": "Unidad Administrativa"
}
```

**Required Fields**:
- `asuntoUnidad` (string): Subject or organizational unit

**Optional Fields**:
- `titulo` (string): Document title
- `serie` (string): Document series
- `productor` (string): Producer/originator

**Response**: `200 OK`
```json
{
  "code": "CODI/01",
  "tituloSerie": "ACTAS DE SESIONES",
  "plazoConservacionAnios": 30,
  "temporalidad": "Permanente",
  "destino": "Conservación Permanente",
  "descripcionInventario": "Documentos del Consejo Directivo"
}
```

**Response Fields**:
- `code`: TRD classification code (null if no match)
- `tituloSerie`: Title of the document series
- `plazoConservacionAnios`: Retention period in years
- `temporalidad`: "Permanente" or "Temporal"
- `destino`: Disposition ("Conservación Permanente", "Eliminación", or "Transferencia al Archivo Central")
- `descripcionInventario`: Inventory description (optional)

**Fallback Behavior**:
If no matching TRD rule is found, returns default values:
```json
{
  "code": null,
  "tituloSerie": "Correspondencia",
  "plazoConservacionAnios": 8,
  "temporalidad": "Temporal",
  "destino": "Eliminación"
}
```

**Example**:
```bash
curl -X POST http://127.0.0.1:8000/classify \
  -H "Content-Type: application/json" \
  -d '{
    "asuntoUnidad": "PRESIDENCIA EJECUTIVA",
    "titulo": "Correspondencia general",
    "serie": "Correspondencia"
  }'
```

---

### TRD Information

#### `GET /trd-info`

Get statistics and information about the TRD table.

**Response**: `200 OK`
```json
{
  "total_entries": 150,
  "total_codes": 145,
  "sample_entries": [
    {
      "code": "CODI/01",
      "titulo": "ACTAS DE SESIONES",
      "valor": "Permanente",
      "asunto": "CONSEJO DIRECTIVO",
      "ag": 2,
      "ap": 0,
      "oaa": 28,
      "total": 30
    },
    ...
  ],
  "index_tokens": 50,
  "inventory_descriptions": 120
}
```

**Response Fields**:
- `total_entries`: Total number of TRD entries
- `total_codes`: Number of unique TRD codes
- `sample_entries`: First 5 TRD entries (for preview)
- `index_tokens`: Number of indexed token rules
- `inventory_descriptions`: Number of inventory descriptions

**Example**:
```bash
curl http://127.0.0.1:8000/trd-info
```

---

### Export Inventory

#### `GET /export/inventory`

Export the complete TRD inventory as an Excel file.

**Response**: `200 OK`
- Content-Type: `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- Content-Disposition: `attachment; filename=inventario_trd.xlsx`

**Excel Format**:
- **Sheet Name**: "Inventario TRD"
- **Headers** (styled with blue background #366092, bold, white text):
  - Código
  - Título Serie
  - Asunto
  - Plazo (años)
  - Temporalidad
  - Destino
  - AG
  - AP
  - OAA
  - Total

- **Data**: All TRD entries with auto-adjusted column widths

**Error Response**:
- `501 Not Implemented`: openpyxl not installed

**Example**:
```bash
curl -O -J http://127.0.0.1:8000/export/inventory
# Downloads as inventario_trd.xlsx
```

**Python Example**:
```python
import requests

response = requests.get("http://127.0.0.1:8000/export/inventory")
with open("inventario_trd.xlsx", "wb") as f:
    f.write(response.content)
```

---

### Reload TRD Data

#### `POST /reload`

Reload TRD data from disk without restarting the server.

**Authentication** (Optional):
If `ADMIN_RELOAD_TOKEN` environment variable is set, requires authentication.

**Request Headers**:
- `X-Admin-Token`: Admin token (required if `ADMIN_RELOAD_TOKEN` is set)

**Response**: `200 OK`
```json
{
  "ok": true,
  "counts": {
    "trd_tabla": 150,
    "indice_tokens": 50,
    "inventario_descripcion": 120
  }
}
```

**Error Responses**:
- `403 Forbidden`: Invalid or missing admin token
- `500 Internal Server Error`: Failed to reload data

**Example (without auth)**:
```bash
curl -X POST http://127.0.0.1:8000/reload
```

**Example (with auth)**:
```bash
curl -X POST http://127.0.0.1:8000/reload \
  -H "X-Admin-Token: your-secret-token"
```

---

## Data Models

### ClassifyRequest

```json
{
  "asuntoUnidad": "string (required)",
  "titulo": "string (optional)",
  "serie": "string (optional)",
  "productor": "string (optional)"
}
```

### ClassifyResponse

```json
{
  "code": "string | null",
  "tituloSerie": "string",
  "plazoConservacionAnios": "integer",
  "temporalidad": "string",
  "destino": "string",
  "descripcionInventario": "string (optional)"
}
```

### TRDEntry

```json
{
  "code": "string",
  "titulo": "string",
  "asunto": "string",
  "valor": "string",
  "ag": "integer",
  "ap": "integer",
  "oaa": "integer",
  "total": "integer",
  "destino": "string (optional)"
}
```

---

## Error Handling

All endpoints return consistent error responses:

```json
{
  "detail": "Error message description"
}
```

### Common Status Codes

- `200 OK`: Request successful
- `400 Bad Request`: Invalid input data
- `403 Forbidden`: Authentication required or failed
- `404 Not Found`: Resource not found
- `413 Payload Too Large`: File exceeds size limit
- `500 Internal Server Error`: Server error
- `501 Not Implemented`: Feature not available

---

## Rate Limiting

Currently, no rate limiting is enforced. In production, consider implementing:
- Per-IP rate limits (e.g., 100 requests/minute)
- Per-endpoint rate limits
- Burst allowance for legitimate traffic

Recommended headers (not yet implemented):
- `X-RateLimit-Limit`: Maximum requests per window
- `X-RateLimit-Remaining`: Remaining requests
- `X-RateLimit-Reset`: Time when limit resets

---

## Security

### File Upload Security

The `/upload` endpoint implements several security measures:

1. **Path Traversal Protection**: Filenames are sanitized to prevent directory traversal
2. **File Size Validation**: Maximum 20MB per file (configurable via `MAX_UPLOAD_BYTES`)
3. **Extension Validation**: Only PDF files are processed
4. **Streaming Upload**: Files are read in 8KB chunks to prevent memory exhaustion

### Authentication

The `/reload` endpoint supports optional token-based authentication:
- Set `ADMIN_RELOAD_TOKEN` environment variable
- Include token in `X-Admin-Token` header
- Leave unset for open access (development only)

### Recommendations for Production

1. **Enable HTTPS**: Use reverse proxy (nginx/caddy) with TLS
2. **Set Admin Token**: Configure `ADMIN_RELOAD_TOKEN`
3. **Implement Rate Limiting**: Use middleware or reverse proxy
4. **Add CORS**: Configure allowed origins
5. **Enable Logging**: Monitor access and errors
6. **Use Authentication**: Implement JWT or OAuth2 for sensitive endpoints

---

## Performance

### Caching

The TRD engine implements LRU caching for performance:
- `normaliza()`: 128 entries (text normalization)
- `buscar_trd_por_codigo()`: 256 entries (code lookup)

Cache is cleared automatically when TRD data is reloaded via `/reload`.

### Response Times

Typical response times (development environment):
- `/health`: < 10ms
- `/classify`: < 50ms
- `/trd-info`: < 100ms
- `/upload` (5MB PDF): < 2s
- `/export/inventory`: < 1s

### Scalability

For production deployments:
- Use multiple Uvicorn workers (`--workers 4`)
- Deploy behind load balancer
- Use Redis for shared cache
- Consider CDN for static assets
- Monitor with Prometheus/Grafana

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `UPLOAD_DIR` | `data/uploads` | Directory for uploaded files |
| `DATA_DIR` | `data` | Base data directory |
| `MAX_UPLOAD_BYTES` | `20000000` | Max file size (20MB) |
| `ADMIN_RELOAD_TOKEN` | (none) | Optional token for `/reload` |
| `LOG_LEVEL` | `INFO` | Logging level |

---

## Examples

### Complete Upload and Classification Workflow

```python
import requests

# 1. Check API health
health = requests.get("http://127.0.0.1:8000/health")
assert health.json()["ok"] is True

# 2. Upload PDF for classification
with open("documento.pdf", "rb") as f:
    response = requests.post(
        "http://127.0.0.1:8000/upload",
        files={"file": f}
    )

result = response.json()
print(f"Classification: {result['classification']['code']}")
print(f"Title: {result['classification']['tituloSerie']}")
print(f"Retention: {result['classification']['plazoConservacionAnios']} years")

# 3. Manual classification (without file)
classify_response = requests.post(
    "http://127.0.0.1:8000/classify",
    json={
        "asuntoUnidad": "CONSEJO DIRECTIVO",
        "titulo": "Actas",
        "serie": "Sesiones"
    }
)
print(classify_response.json())

# 4. Get TRD statistics
info = requests.get("http://127.0.0.1:8000/trd-info")
print(f"Total entries: {info.json()['total_entries']}")

# 5. Export inventory
inventory = requests.get("http://127.0.0.1:8000/export/inventory")
with open("inventario.xlsx", "wb") as f:
    f.write(inventory.content)
```

---

## Changelog

### Version 2.0 (Current)

- Added `/trd-info` endpoint for TRD statistics
- Added `/export/inventory` endpoint for Excel export
- Enhanced `/upload` with automatic classification
- Implemented LRU caching for performance
- Added comprehensive test suite (25 tests)
- Security improvements (path traversal protection, file validation)

### Version 1.0

- Initial release
- `/health`, `/classify`, `/reload` endpoints
- Basic TRD classification engine
- PDF upload support

---

## Support

**Documentation**: See `ARCHITECTURE.md` for system architecture details

**Issues**: Report bugs and feature requests via GitHub Issues

**Contact**: See repository maintainers

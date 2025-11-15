# Catalogador Configuration Directory

## Overview

This directory contains centralized configuration for the Catalogador system, providing a **single source of truth** for deployment, API settings, and service configuration.

## Files

### `backend.config.json`
Main configuration file for the backend API and Windows service deployment.

**Configuration Sections:**

1. **backend** - API server configuration
   - `host`: Bind address (default: `127.0.0.1`)
   - `port`: Port number (default: `8000`)
   - `protocol`: HTTP/HTTPS protocol
   - `timeout_seconds`: Client timeout (default: 300s / 5 minutes)
   - `healthcheck_endpoint`: Health check path (default: `/health`)
   - `healthcheck_timeout_seconds`: Health check timeout (default: 5s)

2. **service** - Windows service configuration
   - `name`: Service name used by NSSM (default: `Catalogador-PythonAPI`)
   - `display_name`: Display name in Windows Services
   - `description`: Service description
   - `startup_type`: Auto/Manual/Disabled startup
   - `restart_delay_ms`: Restart delay on failure (default: 5000ms)

3. **deployment** - Deployment paths and settings
   - `production_root`: Production install path (default: `C:\ProgramData\Catalogador\python_api`)
   - `venv_path`: Virtual environment directory (relative, default: `venv`)
   - `python_module`: ASGI module path (default: `api.main:app`)
   - `log_directory`: Log directory (relative, default: `logs`)
   - `backup_retention_days`: Backup retention period (default: 7 days)

4. **features** - Feature flags
   - `auto_reload_dev`: Enable development auto-reload (default: `false`)
   - `cors_enabled`: Enable CORS middleware (default: `true`)
   - `swagger_ui`: Enable Swagger UI at `/docs` (default: `true`)
   - `admin_token_required`: Require admin token for admin endpoints (default: `true`)

### `backend.config.schema.json`
JSON Schema for validation of `backend.config.json`. Ensures configuration correctness with type checking and constraints.

## Usage

### PowerShell Scripts

```powershell
# Load configuration
$configPath = Join-Path $PSScriptRoot '..\config\backend.config.json'
$config = Get-Content $configPath | ConvertFrom-Json

# Access values
$apiPort = $config.backend.port
$serviceName = $config.service.name
$productionRoot = $config.deployment.production_root
```

### C# Desktop Application

```csharp
using System.Text.Json;

// Load configuration
var configPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "config", "backend.config.json");
var configJson = File.ReadAllText(configPath);
var config = JsonSerializer.Deserialize<BackendConfig>(configJson);

// Access values
var baseUrl = $"{config.Backend.Protocol}://{config.Backend.Host}:{config.Backend.Port}";
```

### Python Scripts

```python
import json
from pathlib import Path

# Load configuration
config_path = Path(__file__).parent.parent / 'config' / 'backend.config.json'
with open(config_path) as f:
    config = json.load(f)

# Access values
api_port = config['backend']['port']
service_name = config['service']['name']
```

## Benefits

✅ **Single Source of Truth** - All components read from one configuration file  
✅ **Type Safety** - JSON Schema validates configuration correctness  
✅ **Easy Updates** - Change port/paths in one place, affects all components  
✅ **Documentation** - Schema includes descriptions for all fields  
✅ **Version Control** - Configuration changes tracked in Git  
✅ **Consistency** - No more hardcoded values scattered across codebase

## Migration Checklist

- [x] Create centralized `backend.config.json`
- [ ] Update `tools/get_backend_port.ps1` to read from config
- [ ] Update `tools/auto_redeploy_catalogador.ps1` to use config
- [ ] Update `tools/install_windows_service.ps1` to use config
- [ ] Update `Catalogador.App/Services/ApiClient.cs` to read config
- [ ] Update all PowerShell deployment scripts
- [ ] Remove hardcoded port values from codebase
- [ ] Add config validation to CI/CD pipeline
- [ ] Update documentation with config usage examples

## Environment Overrides

Configuration can be overridden using environment variables:

- `CATALOGADOR_BACKEND_PORT` - Override API port
- `CATALOGADOR_BACKEND_HOST` - Override API host
- `CATALOGADOR_SERVICE_NAME` - Override service name
- `CATALOGADOR_PRODUCTION_ROOT` - Override production deployment path

**Precedence Order:**
1. Environment variables (highest priority)
2. `backend.config.json` file
3. Fallback defaults in code (lowest priority)

## Security Considerations

🔒 **Sensitive Data:** This configuration file does NOT contain secrets. Admin tokens, API keys, and passwords should be stored in:
- Windows environment variables
- Azure Key Vault
- Secure credential storage (Windows Credential Manager)

⚠️ **Do NOT commit secrets to `backend.config.json`**

## Validation

Validate configuration against schema:

```powershell
# PowerShell validation (requires ajv-cli or similar)
ajv validate -s config\backend.config.schema.json -d config\backend.config.json
```

```bash
# Python validation
python -c "import json, jsonschema; jsonschema.validate(json.load(open('config/backend.config.json')), json.load(open('config/backend.config.schema.json')))"
```

## Troubleshooting

**Issue:** Scripts still using hardcoded port 8000  
**Solution:** Scripts need to be updated to read from config file. See migration checklist above.

**Issue:** Port conflict with another service  
**Solution:** Update `backend.port` in config and restart service:
```powershell
$config = Get-Content config\backend.config.json | ConvertFrom-Json
$config.backend.port = 8001
$config | ConvertTo-Json -Depth 10 | Set-Content config\backend.config.json
```

**Issue:** Configuration changes not taking effect  
**Solution:** Restart the Windows service and desktop application:
```powershell
nssm restart Catalogador-PythonAPI
```

## Version History

- **1.0.0** (2025-11) - Initial centralized configuration system

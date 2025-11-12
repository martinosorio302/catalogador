# 🚀 GUÍA DE INICIO RÁPIDO - CATALOGADOR ESSALUD

## ⚡ Instalación Rápida (5 minutos)

### 1️⃣ Requisitos Previos
```bash
# Verificar instalaciones
python --version    # Debe ser 3.10+
node --version      # Debe ser 18+
git --version       # Debe ser 2.30+
```

### 2️⃣ Clonar e Instalar

#### Windows (PowerShell):
```powershell
# Clonar repositorio
git clone https://github.com/martinosorio302/catalogador.git
cd catalogador

# Instalar Git LFS
git lfs install
git lfs pull

# Backend Python
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Frontend
cd src
npm install
cd ..
```

#### Linux/macOS:
```bash
# Clonar repositorio
git clone https://github.com/martinosorio302/catalogador.git
cd catalogador

# Instalar Git LFS
git lfs install
git lfs pull

# Backend Python
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Frontend
cd src
npm install
cd ..
```

### 3️⃣ Ejecutar

#### Terminal 1 - Backend API:
```bash
# Activar venv si no está activo
.venv/Scripts/Activate.ps1  # Windows
source .venv/bin/activate     # Linux/macOS

# Iniciar API
python -m uvicorn api.main:app --reload
```
**API disponible en:** http://127.0.0.1:8000

#### Terminal 2 - Frontend:
```bash
cd src
npm run dev
```
**Frontend disponible en:** http://localhost:5173

### 4️⃣ Verificar

```bash
# Test API
curl http://127.0.0.1:8000/health

# Ejecutar tests
python -m pytest -v
```

---

## 🎯 Comandos Frecuentes

### Desarrollo:
```bash
# API con hot-reload
python -m uvicorn api.main:app --reload

# Frontend con hot-reload
cd src && npm run dev

# Tests
python -m pytest -v

# Tests específicos
python -m pytest tests/test_api_endpoints.py -v
```

### Build Producción:
```bash
# Build Frontend
cd src && npm run build

# Build Electron (Windows)
npm run electron:build
```

### Windows Service (Producción):
```powershell
# Deploy como servicio (Administrador)
.\tools\final_deploy_catalogador.ps1 -Mode B -Force

# Gestionar servicio
nssm start Catalogador-PythonAPI
nssm stop Catalogador-PythonAPI
nssm restart Catalogador-PythonAPI
```

---

## 📚 Documentación Completa

- **Auditoría Completa:** Ver `AUDIT_REPORT.md`
- **Deployment:** Ver `DEPLOYMENT.md`
- **README Principal:** Ver `README.md`

---

## 🆘 Problemas Comunes

### Error: Module not found
```bash
# Reinstalar dependencias
pip install -r requirements.txt
cd src && npm install
```

### Error: Port already in use
```bash
# Cambiar puerto API
python -m uvicorn api.main:app --port 8001

# Cambiar puerto frontend
cd src && npx vite --port 5174
```

### Error: Permission denied (Windows)
```powershell
# Ejecutar PowerShell como Administrador
Set-ExecutionPolicy Bypass -Scope Process
```

---

## ✅ Checklist de Verificación

- [ ] Python 3.10+ instalado
- [ ] Node.js 18+ instalado
- [ ] Git con LFS instalado
- [ ] Dependencias Python instaladas
- [ ] Dependencias Node instaladas
- [ ] API responde en /health
- [ ] Frontend carga correctamente
- [ ] Tests pasan (11/11)

---

**¿Todo listo?** El sistema está 100% operativo! 🎉

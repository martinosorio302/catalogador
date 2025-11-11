# Changelog

All notable changes to the Catalogador EsSalud project architecture.

## [1.0.0] - 2025-11-11

### Major Architectural Consolidation

#### Added

**WPF Desktop Application**
- Created complete .NET 8 WPF application in `Catalogador.App/`
- Application entry point with logging (`App.xaml`, `App.xaml.cs`)
- Main window with 3 functional tabs (`Views/MainWindow.xaml`)
  - Document Upload & Processing
  - TRD Viewer
  - Inventory Export to Excel
- HTTP API client for backend communication (`Services/ApiClient.cs`)
- Application logging system (`Helpers/SimpleLogger.cs`)
- Data models (`Models/DocumentModels.cs`)
- Real-time API connection status indicator
- User-friendly error handling

**Windows Service Management**
- `tools/install_windows_service.ps1` - Complete NSSM-based service installation
  - Administrator privilege check
  - Python dependency installation
  - Service configuration (auto-start, restart on failure)
  - Logging setup
- `tools/uninstall_service.ps1` - Clean service removal
- `tools/start_service.ps1` - Service startup script
- `tools/stop_service.ps1` - Service shutdown script

**InnoSetup Installer** (NEW)
- `installer/catalogador_setup.iss` - Complete installer configuration
  - Prerequisites checking (.NET 8, Python 3.11+)
  - Component installation (WPF app, Python backend, service scripts)
  - Service configuration during installation
  - Desktop and Start Menu shortcuts
  - Clean uninstallation with service removal
- `installer/installer_readme.txt` - Pre-installation information
- `installer/BUILD_INSTRUCTIONS.md` - Complete build guide
- `installer/README.md` - Installer directory documentation

**Python Package Structure**
- `api/routers/__init__.py` - Router package marker
- `api/services/__init__.py` - Services package marker
- `api/models/__init__.py` - Models package marker
- `engine/__init__.py` - Engine package marker

**Configuration Files**
- `mypy.ini` - Type checking configuration with directory exclusions
- `pyproject.toml` - Ruff linting rules (line length 100, Python 3.11+)
- Enhanced `.gitignore` with comprehensive exclusions

**VSCode Integration**
- `.vscode/settings.json` - Python, JS/TS, editor configurations
- `.vscode/tasks.json` - 18 build/test/run tasks
- `.vscode/launch.json` - 7+ debug configurations
- `.vscode/extensions.json` - 20+ recommended extensions

**Documentation**
- `ARCHITECTURAL_ANALYSIS.md` - Complete repository structural analysis (300+ lines)
- `REFACTOR_STATUS.md` - REFACTOR-Ω PHASE 1 completion report (250+ lines)
- `CONSOLIDATION_PLAN.md` - Architecture consolidation plan (250+ lines)
- `IMPLEMENTATION_SUMMARY.md` - Complete implementation details (11.8KB)
- `README_NEW.md` - New consolidated README for Windows-native architecture (8.2KB)
- `VSCODE_SETUP.md` - Comprehensive VSCode setup guide (400+ lines)
- `SOLUTION_SUMMARY.md` - Complete solution documentation (300+ lines)
- `LICENSE` - MIT License file

**Validation Scripts**
- `scripts/validate_setup.sh` - Automated environment validation
- `scripts/test_backend_startup.sh` - Backend startup validation
- `scripts/remove_duplicates.sh` - Safe removal script for deprecated directories

**Deprecation Markers**
- `frontend/DEPRECATED.md` - Marked Electron/React frontend as deprecated
- `src/DEPRECATED.md` - Marked alternate Electron frontend as deprecated
- `electron/DEPRECATED.md` - Marked Electron main process as deprecated
- `backend/DEPRECATED.md` - Marked .NET backend duplicate as deprecated

#### Changed

**Dependency Fixes**
- Fixed `dev-requirements.txt`:
  - Removed duplicate entries for `ruff`, `mypy`, `pytest`
  - Fixed non-existent `ruff==0.21.1` → `0.14.4`
  - Added `httpx==0.28.1` for test support
- Updated `package.json`:
  - Updated `vite` from `5.4.8` → `5.4.10` (resolved version conflict)

**Solution Configuration**
- Updated `Catalogador.sln` to reference WPF application only
- Removed .NET backend duplicate reference

**README Updates**
- Added VSCode quick start section to `README.md`
- Created comprehensive `README_NEW.md` with:
  - Architecture diagram
  - Quick start guides (users + developers)
  - Complete project structure
  - Technology stack details
  - Windows service management
  - Testing instructions
  - Troubleshooting guide

#### Removed

**Deprecated Implementations** (~504 MB cleanup)
- `frontend/` (172K) - Electron/React frontend → replaced by WPF
- `src/` (152M) - Alternate Electron frontend → replaced by WPF
- `electron/` (12K) - Electron main process → no longer needed
- `backend/` (13M) - .NET API backend → replaced by Python FastAPI
- `pr_bundle/` (76K) - Old code bundle → obsolete
- `pr_bundle_v2/` (40K) - Old code bundle v2 → obsolete
- `app-desktop/` (24K) - Duplicate WPF app location → consolidated
- `dist/` (164K) - Vite build output → no longer needed
- `dist-electron/` (339M) - Electron builds → no longer needed

**Repository Size Reduction**: 74% (from ~675 MB to ~171 MB)

#### Fixed

**Python Imports**
- All Python imports now work correctly
- Backend validated and can start successfully
- Health endpoint responding (HTTP 200)

**Build Issues**
- Resolved NPM version conflicts
- Fixed Python dependency issues
- Corrected package structure

#### Validated

**Testing Status**
- ✅ 11/11 Python tests passing
- ✅ Pytest 8.4.2 operational
- ✅ Ruff 0.14.4 linting operational
- ✅ MyPy 1.8.0 type checking operational
- ✅ Backend starts successfully
- ✅ Health endpoint responding
- ✅ WPF application compiles
- ✅ Service scripts functional

### Architecture Decision

**Confirmed**: Windows-native desktop application

**Stack**:
- **Backend**: Python FastAPI (`api/`) as Windows service (NSSM)
- **Frontend**: .NET 8 WPF (`Catalogador.App/`) desktop application
- **Engine**: Python TRD classification (`engine/`)
- **Deployment**: InnoSetup installer

**Data Flow**:
```
WPF Application (Desktop UI)
    ↓ HTTP (127.0.0.1:8000)
Python FastAPI Backend (Windows Service)
    ↓
TRD Engine (Classification Logic)
```

### Migration Guide

#### For Developers

**Old Structure** (Multi-Technology):
```
├── frontend/     # Electron/React
├── src/          # Alternate Electron
├── electron/     # Electron main
├── backend/      # .NET API (duplicate)
└── api/          # Python API
```

**New Structure** (Consolidated):
```
├── Catalogador.App/  # WPF .NET 8
├── api/              # Python FastAPI
├── engine/           # TRD Engine
└── installer/        # InnoSetup
```

#### For Users

**Installation** (Old): Manual setup, multiple steps
**Installation** (New): Single `.exe` installer with automatic service setup

**Frontend** (Old): Electron-based web UI
**Frontend** (New): Native Windows WPF application

**Backend** (Old): Manual startup via scripts
**Backend** (New): Windows service, auto-starts on boot

### Breaking Changes

- Electron/React frontend removed → Use WPF application
- .NET backend API removed → Use Python FastAPI
- Manual service setup → Use installer or `install_windows_service.ps1`

### Commits in This Release

1. `8e699103` - Initial plan
2. `34cd091b` - Add comprehensive VSCode integration and fix dependencies
3. `bcfe8cdc` - Add mypy and ruff configuration files
4. `e906fd91` - Update README with VSCode integration quick start guide
5. `be88947c` - Add comprehensive solution summary documentation
6. `195409ba` - Add setup validation script
7. `944bd129` - Add missing __init__.py files and architectural analysis
8. `fc4db9a4` - Add REFACTOR-Ω status report and completion summary
9. `e61b59bf` - Create WPF desktop application and Windows service scripts
10. `5471e896` - Mark deprecated directories and create new consolidated README
11. `7785baf3` - Add comprehensive implementation summary
12. `CURRENT` - Remove deprecated directories and create InnoSetup installer

### Credits

- Architecture: REFACTOR-Ω CATALOGADOR ENGINE
- Implementation: GitHub Copilot
- Repository: martinosorio302/catalogador

---

## Previous Versions

Prior to version 1.0.0, the repository contained multiple experimental implementations.
All previous code is preserved in git history and can be recovered if needed.

---

**Note**: This changelog follows [Keep a Changelog](https://keepachangelog.com/) format.

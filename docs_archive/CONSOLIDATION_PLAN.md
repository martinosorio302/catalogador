# Architectural Consolidation Plan - Option 1

**Date**: 2025-11-11  
**Decision**: Windows-native desktop application with Python backend service

---

## Confirmed Architecture

### Keep & Enhance
- ✅ **api/** - Python FastAPI backend (Windows service)
- ✅ **engine/** - Python TRD classification engine
- ✅ **Catalogador.App/** - .NET 8 WPF desktop interface
- ✅ **tools/** - Windows service installation scripts
- ✅ **tests/** - Test suite

### Remove
- ❌ **frontend/** - Electron/React frontend (replaced by WPF)
- ❌ **src/** - Alternate Electron frontend
- ❌ **electron/** - Electron main process
- ❌ **backend/** - .NET API backend (replaced by Python)
- ❌ **pr_bundle/** - Old code bundle
- ❌ **pr_bundle_v2/** - Old code bundle v2
- ❌ **app-desktop/** - Duplicate WPF app location

---

## Implementation Steps

### Phase 1: Consolidate WPF Application
1. Move `app-desktop/Catalogador.App/` contents to root `Catalogador.App/`
2. Create proper WPF structure:
   - Views/
   - ViewModels/
   - Services/ (HTTP client to Python API)
   - Models/
   - App.xaml, MainWindow.xaml
3. Configure API client to connect to `http://127.0.0.1:8000`

### Phase 2: Remove Duplicate Implementations
1. Remove `frontend/` directory
2. Remove `src/` directory
3. Remove `electron/` directory
4. Remove `backend/` directory
5. Remove `pr_bundle/` directory
6. Remove `pr_bundle_v2/` directory
7. Remove `app-desktop/` directory (after consolidation)
8. Update `.gitignore` to exclude build artifacts

### Phase 3: Windows Service Configuration
1. Enhance `tools/` scripts:
   - `install_windows_service.ps1` - Install Python API as Windows service
   - `uninstall_service.ps1` - Uninstall service
   - `start_service.ps1` - Start service
   - `stop_service.ps1` - Stop service
2. Create `start_api.bat` for manual testing
3. Add service configuration file

### Phase 4: Installer Configuration
1. Create `installer/` directory
2. Add InnoSetup script (`.iss` file)
3. Include:
   - Application icon
   - License file
   - README
   - Service installation
   - Desktop/Start Menu shortcuts

### Phase 5: Update Documentation
1. Update `README.md` with new architecture
2. Create `DEPLOYMENT.md` for Windows deployment
3. Create `CHANGELOG.md` documenting architecture changes
4. Update `DOCS.md` with usage instructions

### Phase 6: Update Build Configuration
1. Update root `Catalogador.sln` to include only WPF app
2. Remove Electron build scripts from `package.json`
3. Update `.vscode/tasks.json` for new structure

---

## Target Directory Structure

```
Catalogador/
│
├── api/                          # Python FastAPI Backend
│   ├── __init__.py
│   ├── main.py
│   ├── routers/
│   ├── services/
│   └── models/
│
├── engine/                       # TRD Classification Engine
│   ├── __init__.py
│   └── trd.py
│
├── Catalogador.App/              # .NET 8 WPF Desktop App
│   ├── Catalogador.App.csproj
│   ├── App.xaml
│   ├── MainWindow.xaml
│   ├── Views/
│   ├── ViewModels/
│   ├── Services/
│   │   └── ApiClient.cs        # HTTP client to Python API
│   └── Models/
│
├── tools/                        # Windows Service Scripts
│   ├── install_windows_service.ps1
│   ├── uninstall_service.ps1
│   ├── start_service.ps1
│   ├── stop_service.ps1
│   └── nssm.exe
│
├── installer/                    # InnoSetup Configuration
│   ├── catalogador_setup.iss
│   ├── icon.ico
│   ├── license.txt
│   └── readme.txt
│
├── tests/                        # Test Suite
│   └── [existing tests]
│
├── data/                         # Data Files
│   └── essalud_pcd_anexo02.full.json
│
├── scripts/                      # Build & Validation Scripts
│   ├── validate_setup.sh
│   └── test_backend_startup.sh
│
├── .vscode/                      # VSCode Configuration
│   ├── settings.json
│   ├── tasks.json
│   └── launch.json
│
├── Catalogador.sln               # .NET Solution (WPF only)
├── start_api.bat                 # Manual API startup
├── requirements.txt              # Python dependencies
├── dev-requirements.txt          # Python dev dependencies
├── setup.py                      # Python package config
├── mypy.ini                      # Type checking
├── pyproject.toml                # Ruff config
├── pytest.ini                    # Test config
├── README.md                     # Main documentation
└── DOCS.md                       # User guide
```

---

## Files to Remove

### Electron/React Frontend
- `frontend/` (entire directory)
- `src/` (entire directory)
- `electron/` (entire directory)
- `dist/` (Vite build output)
- `dist-electron/` (Electron build output)
- `index.html` (root)
- `vite.config.js` (root)
- `tsconfig.json` (root - if Electron-specific)
- `tsconfig.esm.json` (root - if Electron-specific)
- `package.json` entries for Electron

### Duplicate .NET Backend
- `backend/` (entire directory)

### Old Bundles
- `pr_bundle/` (entire directory)
- `pr_bundle_v2/` (entire directory)

### Duplicate App Location
- `app-desktop/` (entire directory, after consolidation)

### Electron-specific Files
- `electron/main.js`
- `electron/preload.cjs`

---

## Files to Keep & Update

### Python Backend
- `api/**` - Keep all (backend service)
- `engine/**` - Keep all (TRD engine)
- `tests/**` - Keep all (test suite)
- `requirements.txt` - Keep
- `dev-requirements.txt` - Keep
- `setup.py` - Keep

### .NET WPF App
- Consolidate to `Catalogador.App/` in root
- `Catalogador.sln` - Update to reference correct path

### Tools & Scripts
- `tools/**` - Keep and enhance
- `scripts/**` - Keep validation scripts

### Configuration
- `.vscode/**` - Keep and update
- `mypy.ini`, `pyproject.toml`, `pytest.ini` - Keep
- `.gitignore` - Update

### Documentation
- `README.md` - Update
- `VSCODE_SETUP.md` - Update
- `ARCHITECTURAL_ANALYSIS.md` - Archive or update
- Create new `DOCS.md`, `DEPLOYMENT.md`, `CHANGELOG.md`

---

## Success Criteria

After implementation:
- ✅ WPF app runs and connects to Python API
- ✅ Python API starts as Windows service
- ✅ No Electron/React code remains
- ✅ No duplicate backend code remains
- ✅ InnoSetup installer builds successfully
- ✅ All tests still pass
- ✅ Documentation reflects new architecture
- ✅ Service scripts work correctly

---

## Estimated Timeline

- Phase 1 (WPF Consolidation): 30 minutes
- Phase 2 (Remove Duplicates): 15 minutes
- Phase 3 (Service Scripts): 30 minutes
- Phase 4 (Installer Config): 30 minutes
- Phase 5 (Documentation): 30 minutes
- Phase 6 (Build Config): 15 minutes

**Total**: ~2.5 hours

---

## Rollback Plan

If issues arise:
- Git history preserves all removed code
- Can restore any directory with: `git checkout HEAD~N -- path/`
- Tests validate functionality at each step

---

## Next Actions

1. Create proper WPF app structure in `Catalogador.App/`
2. Move and enhance existing WPF code
3. Remove duplicate implementations
4. Create service installer scripts
5. Add InnoSetup configuration
6. Update documentation
7. Validate everything works

**Status**: Ready to execute

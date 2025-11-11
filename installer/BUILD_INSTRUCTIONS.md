# Catalogador EsSalud - Installer Build Instructions

## Prerequisites

1. **Inno Setup 6.x**
   - Download from: https://jrsoftware.org/isdl.php
   - Install with default options

2. **.NET 8 SDK**
   - Required to build the WPF application
   - Download from: https://dotnet.microsoft.com/download/dotnet/8.0

3. **Python 3.11+**
   - Required for backend
   - Download from: https://www.python.org/downloads/

## Build Steps

### 1. Build the WPF Application

```powershell
# From repository root
cd Catalogador.App
dotnet restore
dotnet build -c Release
```

This will create the application in:
`Catalogador.App\bin\Release\net8.0-windows\`

### 2. Prepare Backend Files

Ensure the following are present:
- `api/` directory with all Python backend code
- `engine/` directory with TRD engine
- `requirements.txt`
- `setup.py`

### 3. Build the Installer

```powershell
# From repository root
cd installer

# Compile the InnoSetup script
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" catalogador_setup.iss
```

Or open `catalogador_setup.iss` in Inno Setup and click "Compile".

### 4. Output

The installer will be created in:
`installer\output\CatalogadorEsSalud_Setup_1.0.0.exe`

## Installer Features

The generated installer will:

1. **Check Prerequisites**
   - Verify .NET 8 Desktop Runtime is installed
   - Verify Python 3.11+ is available

2. **Install Components**
   - WPF Desktop Application
   - Python FastAPI Backend
   - Service Management Scripts
   - Data Files & Documentation

3. **Configure Service** (optional)
   - Install Python dependencies
   - Create Windows service with NSSM
   - Configure auto-start
   - Setup logging

4. **Create Shortcuts**
   - Desktop icon (optional)
   - Start Menu entry
   - Uninstaller entry

## Testing the Installer

1. Build the installer following the steps above
2. Run the installer on a clean Windows 10/11 machine
3. Verify the service starts: `nssm status CatalogadorAPI`
4. Launch the application and test connectivity
5. Test document upload and processing
6. Verify uninstaller works correctly

## Customization

### Change Version

Edit `catalogador_setup.iss`:
```iss
#define MyAppVersion "1.0.0"
```

### Change Install Location

Default is `C:\Program Files\Catalogador EsSalud`

Users can change this during installation.

### Add/Remove Components

Edit the `[Files]` section in `catalogador_setup.iss`:
```iss
Source: "path\to\file"; DestDir: "{app}\folder"; Flags: ignoreversion
```

### Service Configuration

Edit service installation parameters in `catalogador_setup.iss`:
```iss
Filename: "powershell.exe"; 
Parameters: "... -Port 8000"
```

## Troubleshooting

### "File not found" during compilation

- Ensure WPF app is built: `dotnet build Catalogador.App -c Release`
- Verify all source paths in `catalogador_setup.iss` exist

### Prerequisites not detected

- Install .NET 8 Desktop Runtime on build machine
- Ensure Python is in PATH: `python --version`

### Service installation fails

- Run installer as Administrator
- Check NSSM is present in `tools\nssm.exe`
- Verify PowerShell execution policy allows scripts

## Distribution

The generated `.exe` installer can be distributed via:
- Direct download
- Network share
- USB drive
- Software deployment tools (SCCM, etc.)

No additional files are needed - the installer is self-contained.

## Size

Expected installer size: ~15-20 MB (compressed)
Installed size: ~50-100 MB

## Support

For issues or questions:
- GitHub: https://github.com/martinosorio302/catalogador
- Documentation: See README.md and IMPLEMENTATION_SUMMARY.md

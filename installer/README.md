# Installer Directory

This directory contains the InnoSetup installer configuration for Catalogador EsSalud.

## Contents

- **catalogador_setup.iss** - InnoSetup script (main installer configuration)
- **installer_readme.txt** - Pre-installation information shown to users
- **BUILD_INSTRUCTIONS.md** - Complete build instructions
- **icon.ico** - Application icon
- **output/** - Generated installer files (not in git)

## Quick Build

1. Build WPF application:
   ```powershell
   dotnet build ..\Catalogador.sln -c Release
   ```

2. Compile installer:
   ```powershell
   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" catalogador_setup.iss
   ```

3. Find installer in: `output\CatalogadorEsSalud_Setup_1.0.0.exe`

## What the Installer Does

- Installs WPF desktop application
- Installs Python backend with dependencies
- Configures Windows service (NSSM-based)
- Creates desktop and start menu shortcuts
- Sets up logging directories
- Provides clean uninstall

## Prerequisites

- Inno Setup 6.x
- .NET 8 SDK (for building WPF app)
- Python 3.11+ (runtime requirement)

## For More Details

See [BUILD_INSTRUCTIONS.md](BUILD_INSTRUCTIONS.md)

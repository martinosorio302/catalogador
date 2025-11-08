# Catalogador - Packaging and Build Guide

This guide explains the automated packaging steps implemented in the repository.

Scripts added

- `npm run build:web` - builds the UI from `src`.
- `npm run build:web:copy` - builds UI in `src` and copies `src/dist` to `dist/web` (calls `tools/build_and_copy.ps1`).
- `npm run electron:build` - runs `build:web:copy` and then runs `electron-builder` to produce an installer. Uses `--publish never`.
- `npm run electron:build:dir` - runs `build:web:copy` and produces the unpacked `win-unpacked` dir for testing.

Prepack helper

- `tools/prepack.ps1` - checks for Visual Studio Code processes that may lock `app.asar` or packaging folders. Run with `-ForceClose` to forcibly close VS Code before packaging.

Recommended packaging workflow (Windows PowerShell)

1) Close Visual Studio Code (or run prepack):

```powershell
# optional: run and allow script to close VS Code
powershell -NoProfile -ExecutionPolicy Bypass -File tools\prepack.ps1 -ForceClose
```

2) Build UI and copy assets to top-level `dist/web`:

```powershell
npm run build:web:copy
```

3) Build unpacked Electron (for testing):

```powershell
npm run electron:build:dir
# run the exe from dist-electron\win-unpacked
Start-Process .\dist-electron\win-unpacked\"Catalogador EsSalud.exe"
```

4) Build installer (after verifying unpacked app):

```powershell
npm run electron:build
```

Notes

- Ensure Node and npm are installed. The UI build runs inside `src` and requires dependencies listed in `src/package.json`.
- The packaging step uses `electron-builder`. If you want auto-update/publish features, add a valid `repository` and `publish` provider in `package.json`.
- Provide a valid multi-resolution `build/icon.ico` if you want a custom icon in the installer.

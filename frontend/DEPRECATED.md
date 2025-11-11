# DEPRECATED - Electron/React Frontend

This directory contains the Electron/React frontend implementation that has been **replaced** by the .NET WPF desktop application (`Catalogador.App/`).

## Status: DEPRECATED

**Decision Date**: 2025-11-11  
**Reason**: Architectural consolidation to Windows-native stack

## New Architecture

The project now uses:
- **Backend**: Python FastAPI (`api/`) as Windows service
- **Frontend**: .NET 8 WPF (`Catalogador.App/`) desktop application

## Migration

All frontend functionality has been reimplemented in the WPF application:
- Document upload → `Catalogador.App/Views/MainWindow.xaml`
- TRD viewer → `Catalogador.App/Views/MainWindow.xaml`
- Inventory export → `Catalogador.App/Services/ApiClient.cs`

## Removal

This directory can be safely removed in a future commit. It is preserved temporarily for reference.

To remove:
```bash
rm -rf frontend/
```

## History

Git history preserves the complete Electron implementation if needed for recovery:
```bash
git checkout fc4db9a4 -- frontend/
```

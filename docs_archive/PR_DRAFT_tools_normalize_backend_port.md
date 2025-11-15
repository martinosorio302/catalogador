# PR draft: Normalize backend port resolution across `tools/`

Summary
-------
This change normalizes how development/service scripts resolve the backend port. It introduces a canonical helper (`tools/get_backend_port.ps1`) and updates tooling to prefer that helper instead of hard-coding `8000`. It also archives stale/duplicate placeholder scripts to `tools/archive/` and adds `tools/README.md` documenting the runtime contract and recommended developer flow.

Key points
----------
- New helper: `tools/get_backend_port.ps1` (returns port or base URL with `-BaseUrl`).
- Launcher: `tools/run_backend_autofix.ps1` is the canonical launcher that writes `runtime/backend_port.txt` and starts the backend on the first free port in 8000..8010.
- Scripts updated to prefer the helper: `auto_import_and_configure_service.ps1`, `auto_redeploy_catalogador.ps1`, `catalogador_full_fix.ps1`, `catalogador_full_fix_safe.ps1`, `generate_nssm_service.ps1`, `install_windows_service.ps1`, `set_nssm_env_and_restart.ps1`, and others under `tools/`.
- Archival: moved older placeholder/backup scripts into `tools/archive/` (no destructive deletions of archived originals).
- Docs: `tools/README.md` describes the runtime contract and workflows.

Why
---
- Developers were frequently blocked by a protected process on 127.0.0.1:8000. The non-destructive fallback approach allows the backend to start on a free port while preserving an audit trail and optional admin workflow to reclaim 8000.
- Centralizing port resolution reduces drift and hard-to-find bugs in service/installer scripts.

Testing performed
-----------------
- Ran `tools/get_backend_port.ps1` (`-BaseUrl`) to validate helper output.
- Ran `tools/run_backend_autofix.ps1` which wrote `runtime/backend_port.txt` and started Uvicorn on a fallback port (observed 8002 during tests).

How to review
-------------
- Focus on `tools/get_backend_port.ps1`, `tools/run_backend_autofix.ps1`, and `tools/README.md` for the runtime contract.
- Spot-check service/installer scripts in `tools/` for usage of the helper.

Follow-ups / TODO
-----------------
- Sweep remaining documentation/example files to remove literal `8000` in comments where they imply a permanent binding.
- Add a CI smoke test that runs the launcher, polls /health and tears it down (non-admin).
- Consider making installed NSSM services write `runtime/backend_port.txt` at install-time or set `UVICORN_PORT` env var to keep consistency.
- Optionally open a PR against remote branch and run CI.

Commands I ran locally
----------------------
```powershell
# show helper output
pwsh -NoProfile -ExecutionPolicy Bypass -Command ".\tools\get_backend_port.ps1 -BaseUrl"
# start canonical launcher
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\run_backend_autofix.ps1
# verify runtime file
Get-Content .\runtime\backend_port.txt
```

If you want, I can now:
- Push this branch and open a PR (requires GitHub remote access/credentials).
- Add a CI workflow that runs a smoke test for the launcher.
- Continue sweeping other folders (e.g., `tools/installers` or templates) to remove literal port examples.

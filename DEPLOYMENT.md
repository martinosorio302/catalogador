Deployment & final operational checklist (Windows)
=================================================

Follow this checklist to finalize a ProgramData NSSM deployment. The repository includes a safe deploy helper at `tools\auto_redeploy_catalogador.ps1`.

Steps to perform (Administrator PowerShell required):

1. Open PowerShell as Administrator.
2. From the repo root run (dry-run shown unless `-Force` is provided):

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd C:\Users\USER\Desktop\Catalogador
.\tools\auto_redeploy_catalogador.ps1 -Mode B    # shows what would be done
```

3. When comfortable, run the final deploy (this performs backup -> copy -> venv -> pip install -> editable install -> configure NSSM -> start service):

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd C:\Users\USER\Desktop\Catalogador
.\tools\auto_redeploy_catalogador.ps1 -Mode B -Force
```

4. Verify health endpoint:

```powershell
Invoke-RestMethod -Uri http://127.0.0.1:8000/health
```

5. Check logs under `C:\ProgramData\Catalogador\python_api\logs` if the service does not start.

Notes:
- The deploy script will create a timestamped backup of the existing ProgramData install before replacing files.
- The script expects `nssm.exe` available on PATH. If missing, place `nssm.exe` on PATH or in a folder included in PATH, or edit the script to point to your `nssm.exe`.
- If you want the script to download and verify `nssm.exe` automatically, reply and I will add an optional download + SHA256 verification step.

If you want me to run the final deploy step, run the above `-Force` command in an elevated PowerShell and paste the output here; I'll analyze and help fix any runtime errors.

@echo off
REM Start Catalogador API with embedded venv if present, otherwise use system python
SET ROOT=%~dp0
SET VENV=%ROOT%venv\Scripts\python.exe
IF EXIST "%VENV%" (
  "%VENV%" -m uvicorn api.main:app --host 127.0.0.1 --port 8000 --log-level info
) ELSE (
  python -m uvicorn api.main:app --host 127.0.0.1 --port 8000 --log-level info
)

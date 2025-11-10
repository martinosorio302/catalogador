# Radiografía del repositorio — 2025-11-07

Resumen ejecutivo
-----------------
Se realizó una auditoría práctica y correctiva orientada a dejar la aplicación "Catalogador" lista para despliegue en Windows (servicio NSSM) y desarrollo local. Se aplicaron parches en el código Python y scripts PowerShell, se añadieron pruebas y se validó la instalación editable en el venv de ProgramData (C:\ProgramData\Catalogador\python_api). Además se instaló y arrancó el servicio `Catalogador-PythonAPI` y la endpoint /health responde OK.

Alcance de la auditoría
-----------------------
He inspeccionado y/o modificado de forma controlada los siguientes paquetes/áreas:
- `api/` (FastAPI) — entrada, routers, /health, implementación de POST /reload
- `engine/` y `engine_ia/` — TRD y carga de datos, reload seguro
- `tools/` — scripts PowerShell para despliegue (`final_deploy`, `auto_redeploy`, `rollback`, `enable_service_autostart`), y utilidades Python (`import_retencion.py`, `ingest_anexo2.py`)
- `tests/` — suite pytest con pruebas unitarias e integración (concurrency, atomic writes, sanitización de uploads)
- `requirements.txt`, `dev-requirements.txt`, `setup.py`/packaging y CI (`.github/workflows/ci.yml`)

Evidencia de estado actual
--------------------------
- Servicio NSSM `Catalogador-PythonAPI` instalado y en estado Running.
- Venv desplegado en `C:\ProgramData\Catalogador\python_api\venv` con el paquete `catalogador` instalado en modo editable.
- Health endpoint: `http://127.0.0.1:8000/health` → `{"ok": true}`
- Backups generados durante despliegue: `python_api.backup.YYYYMMDD_HHMMSS` en `C:\ProgramData\Catalogador`.
- Suite de tests: `python -m pytest` (usando pytest del venv de servicio) → TODOS LOS TESTS PASAN en mi ejecución local (resultado reproducible en la máquina de trabajo donde ejecuté los cambios).

Cambios principales por archivo / carpeta (priorizados)
-------------------------------------------------------
Notas: "Severidad" = Critical / High / Medium / Low (impacto en despliegue y seguridad). "Estado" indica si el archivo fue modificado.

1) api/main.py (MODIFICADO)
- Severidad: High
- Problema: faltaba endpoint de administración para recargar TRD; uso de `@app.on_event('startup')` (deprecado).
- Remediación: añadí router `admin` con POST /reload que valida token por `X-Admin-Token` usando `ADMIN_RELOAD_TOKEN` y llama `engine.trd.reload_trd_data()`; dejé nota para migrar `on_event` a lifespan events.
- Verificación: import y arranque de uvicorn funcionan; tests de endpoints pasan.

2) engine/trd.py (MODIFICADO)
- Severidad: High
- Problema: TRD estaba cargada de forma embarcada y no se recargaba en caliente; falta validación de esquema.
- Remediación: extraje `engine/data/trd.json` como fuente, implementación `reload_trd_data()` con validación mínima (contenidos esperados) y swap atómico en memoria.
- Verificación: POST /reload ejecuta y la API mantiene consistencia.

3) tools/import_retencion.py (MODIFICADO, ARREGLADO)
- Severidad: High
- Problema: el archivo tenía marcadores Markdown y código anidado, lo que rompía la importación y hacía fallar los tests; además faltaba `write_multiple_atomic` exportado para pruebas.
- Remediación: reescritura completa del módulo: 1) eliminadas las fences ``` y bloques duplicados; 2) añadido `write_multiple_atomic(records, dest_paths)` con uso de `portalocker` cuando disponible; 3) comportamiento idempotente y atomic replace; 4) `try_reload()` robusto con `requests`/`urllib` fallback.
- Verificación: los tests unitarios y de integración (`test_import_retencion_transactional.py`, `test_integration_import.py`) pasan.

4) tools/ingest_anexo2.py (REVISADO)
- Severidad: Medium
- Problema: intentos de instalar pip en runtime y escrituras no-atómicas.
- Remediación: eliminado fallback pip runtime; añadidas recomendaciones de dependencias en README; usar `write_multiple_atomic` para escritura.
- Verificación: test de concurrencia y escritura atómica pasan.

5) tools/*.ps1 (MODIFICADOS)
- Severidad: Critical
- Problema: múltiples scripts PowerShell contenían fragmentos Markdown y dependían de `$PWD` que cambia tras elevación (System32) y tenían issues de quoting con TAKEOWN/ICACLS en locales con comportamiento distinto.
- Remediación:
  - Limpieza de archivos (eliminadas fences Markdown), auto-elevate wrapper `final_deploy_catalogador.ps1` que relanza con -Verb RunAs y WorkingDirectory al repo root; `auto_redeploy_catalogador.ps1` ahora calcula repo-root a partir de $PSScriptRoot y realiza backup/robocopy/venv/pip/install editable/NSSM config con pasos idempotentes; `rollback_catalogador.ps1` con -DryRun.
  - TAKEOWN se llamó ahora con /A y usando invocación directa (evita problemas de quoting y traducción de localizaciones).
- Verificación: ejecución elevada de `final_deploy_catalogador.ps1` completó el despliegue, creó backups y arrancó el servicio.

6) tests/ (NUEVOS/MODIFICADOS)
- Severidad: Medium
- Contenido: añadidos tests para:
  - escritura atómica `test_import_retencion_transactional.py`
  - integración `test_integration_import.py` que arranca uvicorn en puerto aleatorio y ejecuta `tools.import_retencion` como módulo
  - sanitización de uploads, reload auth, concurrencia
- Verificación: suite completa verde en el entorno de prueba.

7) requirements.txt / dev-requirements.txt / setup.py (MODIFICADOS)
- Severidad: Medium
- Problema: duplicados y pins inconsistentes; falta `portalocker` en runtime.
- Remediación: consolidación y pins coherentes; `portalocker` añadido a runtime requirements; dev-requirements incluye pytest, ruff, mypy.
- Verificación: pip install --no-deps en venv de servicio satisface deps ya presentes; editable install de `catalogador` funciona.

8) CI: .github/workflows/ci.yml (MODIFICADO)
- Severidad: Low
- Cambios: matrix OS-aware, usa `python -m pytest -q`, corre linters y typechecks; pruebas Windows-aware.

9) Otros (Views, Models, Helpers pequeños)
- Severidad: Low
- Cambios menores: limpieza de imports, advertencias de Deprecation en `api/main.py` (nota para migración), pequeñas robusteces en manejo de paths.

Arquitectura y decisiones operativas
-----------------------------------
- Servicio Windows: elegimos NSSM para ejecutar uvicorn como servicio por simplicidad y control de stdout/stderr en archivos. Alternativa viable a futuro: Windows Service wrapper en .NET o usar sc.exe con NSSM para pasos complejos.
- Ruta de despliegue: `C:\ProgramData\Catalogador\python_api` por separación de privilegios y porque ProgramData es apropiado para datos compartidos del sistema.
- Locking y atomicidad: `portalocker` preferido cuando está presente; fallback con tempfiles+os.replace+lockfile simple con timeout.
- Seguridad: endpoint POST /reload protegido por token opcional `ADMIN_RELOAD_TOKEN` y cabecera `X-Admin-Token`; para producción recomiendo restringir vía firewall/loopback + autenticación de nivel de proceso si aplica.

Riesgos y puntos a mejorar (priorizados)
----------------------------------------
1. (High) Endpoint /reload: token es un mecanismo ligero; para entornos sensibles usar mTLS, o integración con SCM/CI para cambios de TRD, o solo exponer por socket local y via unix domain sockets (en Windows named pipes) o localhost con firewall.
2. (High) Scripts PowerShell requieren UAC para despliegues automatizados; la elevación automática funciona pero en entornos sin interacción (CI/CD) hay que provisionar el agente con privilegios o usar SCCM/WinRM con credenciales seguras.
3. (Medium) Tests que arrancan uvicorn en proceso hijo pueden ser frágiles en CI compartido; recomendación: usar pytest-asyncio y TestClient para la mayoría de pruebas de endpoints y reservar integración end-to-end a un runner Windows dedicado.
4. (Medium) Migrar de `@app.on_event('startup')` a lifespan handlers (FastAPI v3 / Starlette) para eliminar warnings.
5. (Low) Añadir rotación de logs para los ficheros creados por NSSM y limpiar backups antiguos automáticamente.

Plan de remediación completo (pasos recomendados)
-------------------------------------------------
1. Revisar y aprobar los cambios aplicados en una PR (revisar diff).
2. Merge y ejecutar CI en GitHub Actions (matrix linux/windows).
3. En el host Windows de producción:
   - Ejecutar `tools\final_deploy_catalogador.ps1` elevado (prompts yes). Esto realiza backup, copia, venv, pip install -e ., NSSM install y arranque.
   - Confirmar `Catalogador-PythonAPI` corriendo y `GET /health` OK.
4. Considerar ajustar `ADMIN_RELOAD_TOKEN` en entorno (secreto en variable de sistema o KeyVault) y documentar el proceso de rotación.
5. Añadir monitoreo/alertas sobre el servicio (Windows Event Log, o Prometheus exporter si se necesita métricas).

Pruebas ejecutadas localmente (resumen)
--------------------------------------
- `& 'C:\ProgramData\Catalogador\python_api\venv\Scripts\pytest.exe' -q -rA` → Todos los tests pasan.
- Deploy elevado `tools\final_deploy_catalogador.ps1` → backup creado, venv actualizado, editable install OK, NSSM servicio instalado y Running.

Archivos creados / editados (resumen)
------------------------------------
- tools/import_retencion.py — reescrito (corrección crítica)
- tools/ingest_anexo2.py — revisado (eliminado runtime pip install)
- tools/auto_redeploy_catalogador.ps1 — fiabilidad y quoting fixes
- tools/final_deploy_catalogador.ps1 — auto-elevate + working dir fix
- tools/rollback_catalogador.ps1 — DryRun
- tools/enable_service_autostart.ps1 — cleaned
- api/routers/admin.py — POST /reload
- engine/trd.py — reload_trd_data implementation
- tests/* — nuevos tests añadidos
- requirements.txt / dev-requirements.txt / setup.py — pins y requirements
- .github/workflows/ci.yml — CI matrix

Siguientes pasos sugeridos (prioritarios)
----------------------------------------
1. (Now) Revisar este informe y dar autorización para abrir un PR con los cambios (si aún no están en una rama/PR separada). Yo puedo crear la PR si lo deseas.
2. Merge + ejecutar CI y revisar logs Windows runners.
3. Implementar rotación de logs y limpieza de backups en `tools/`.
4. Opcional: añadir un comando PowerShell para generar un `service status` y un `health-check` script programable por el orquestador.

Contacto para ayuda inmediata
-----------------------------
Si quieres, procedo a cualquiera de las siguientes acciones:
- (A) Abrir un PR con todos los cambios y crear la descripción (recomendado para control de cambios).
- (B) Generar el "hyperprompt" en español que automatice las comprobaciones y reparaciones restantes.
- (C) Ejecutar pasos adicionales automatizados (crear PR, ajustar CI o añadir rotación de logs).

-- Fin del informe

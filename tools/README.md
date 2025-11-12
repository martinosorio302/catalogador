# Tools: runtime contract and helper

Este directorio contiene utilidades y scripts PowerShell para desplegar y ejecutar el backend API de Catalogador en Windows.

Objetivo principal
- Proveer un punto canónico para resolver el puerto/URL del backend local: `tools/get_backend_port.ps1`.
- Evitar hard-coding del puerto `8000` en scripts y plantillas; preferir la resolución canónica.

Resolución de puerto (orden de preferencia)
1. Variable de entorno `CATALOGADOR_BACKEND_PORT` (o `UVICORN_PORT`).
2. Contenido de `runtime/backend_port.txt` (creado por `tools/run_backend_autofix.ps1`).
3. Si no hay nada, valor por defecto `8000`.

Helper principal
- `tools/get_backend_port.ps1` — devuelve por stdout el puerto (ej. `8002`) o, con la opción `-BaseUrl`, la URL base (`http://127.0.0.1:8002`).

Uso recomendado en scripts PowerShell
- Para obtener el puerto en un script:

```powershell
$portHelper = Join-Path $PSScriptRoot 'get_backend_port.ps1'
if (Test-Path $portHelper) { $ApiPort = [int](& $portHelper) } else { $ApiPort = 8000 }
```

- Para obtener la URL base en llamadas HTTP:

```powershell
$base = & $portHelper -BaseUrl
Invoke-RestMethod -Uri ("$base/health")
```

Flujo de arranque local (desarrolladores)
1. Ejecutar el lanzador canónico (no-administrativo):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\run_backend_autofix.ps1
```

Esto selecciona primero `8000` (si está libre) o la primera puerta libre en `8001..8010`, escribe `runtime/backend_port.txt` de forma atómica y arranca Uvicorn usando el `python` del entorno virtual `.venv` (si existe) o `python` del PATH.

Servicios y NSSM
- Los scripts que crean/actualizan servicios (p. ej. `generate_nssm_service.ps1`, `install_windows_service.ps1`) ahora prefieren resolver el puerto vía `tools/get_backend_port.ps1`. Se recomienda, en sistemas administrados, ajustar el servicio para que lea `UVICORN_PORT` o que el instalador escriba `runtime/backend_port.txt`.

Diagnósticos y recuperación de 8000
- `tools/identify_owner_port8000.ps1` genera diagnósticos sobre quién escucha en `:8000` y escribe `runtime/port8000_owner.json`. No realiza paradas o kills por defecto; requiere `-ForceStop` para acciones destructivas (administrador).

Notas de mantenimiento
- Si encuentras scripts antiguos que aún contienen `8000` incrustado en comentarios o parámetros, actualízalos para usar el helper o para documentar claramente que ese valor es solo un ejemplo.
- Los scripts antiguos y copias de seguridad se han movido a `tools/archive/` para referencia.

Contacto
- Si necesitas que haga un barrido adicional (reemplazar todas las apariciones restantes), responde con "normalizar todo" y procederé a actualizar el resto de `tools/` y preparar un PR.

---

Sección: despliegue en producción (NSSM)
--------------------------------------
Para entornos Windows administrados recomendamos empaquetar e instalar el backend con NSSM. Hemos añadido dos scripts seguros y con comportamiento por defecto no destructivo:

- `tools/install_production_service.ps1` — instalador idempotente del servicio. Características clave:
	- Comprueba disponibilidad del puerto (por defecto 8000) y escribe diagnósticos en `runtime/` si está ocupado.
	- Descarga NSSM automáticamente en `%ProgramData%\nssm` si no está presente (interactivo).
	- Configura el servicio para ejecutar: `python -m uvicorn api.main:app --host 127.0.0.1 --port <port>`
	- Establece reinicio automático y rutas de logs en `%ProgramData%\Catalogador\logs`.
	- Escribe `runtime/backend_port.txt` de forma atómica.
	- Intenta arrancar y hace una comprobación rápida de `/health`.

- `tools/uninstall_production_service.ps1` — desinstalador que detiene y elimina el servicio, con opción `-RemoveRuntime` para borrar `runtime/backend_port.txt`.

Consideraciones de seguridad y operaciones
- Ambos scripts intentan relanzarse con privilegios de Administrador si no se ejecutan con derechos suficientes (salvo que se use `-WhatIf`).
- Por defecto no se mata ningun proceso externo que ocupe el puerto; pase `-Force` solo si comprende el impacto.
- Pruebe las acciones en una VM antes de proceder en sistemas de producción.

Ejemplo (simulación, sin cambios):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\install_production_service.ps1 -Port 8000 -WhatIf
```

Si quieres que proceda a instalar el servicio en tu entorno (o que genere una PR con los cambios), dime: "instala servicio" o "crear PR" y lo hago.

# 🚀 GUÍA RÁPIDA - Catalogador EsSalud

## ❓ Error: "no se reconoce como un comando"

Si ves este error al intentar ejecutar el lanzador:
```
"LAUNCH_CATALOGADOR.bat" no se reconoce como un comando interno o externo,
programa o archivo por lotes ejecutable.
```

**Causa:** Estás intentando ejecutar el comando desde un directorio incorrecto o sin el prefijo correcto.

## ✅ SOLUCIONES

### Solución 1: Doble Clic (MÁS FÁCIL) ⭐

1. Abre el Explorador de Windows
2. Navega a la carpeta `catalogador`
3. **Doble clic** en uno de estos archivos:
   - `START.bat` (recomendado - más simple)
   - `LAUNCH_CATALOGADOR.bat`
   - `LAUNCH_CATALOGADOR.ps1`

¡Eso es todo! La aplicación se iniciará automáticamente.

### Solución 2: Desde CMD (con prefijo)

Si prefieres usar la línea de comandos:

```cmd
REM Navega al directorio correcto
cd C:\Users\USER\catalogador

REM IMPORTANTE: Usa .\ antes del nombre del archivo
.\START.bat

REM O alternativamente:
.\LAUNCH_CATALOGADOR.bat
```

**Nota importante:** En Windows CMD, debes usar `.\` antes del nombre del archivo o simplemente ejecutarlo sin prefijo si estás en el directorio correcto.

### Solución 3: Crear Acceso Directo en el Escritorio

Para mayor comodidad:

1. **Doble clic** en `CREATE_DESKTOP_SHORTCUT.bat`
2. Se creará automáticamente un acceso directo en tu escritorio
3. Usa ese acceso directo para iniciar la aplicación

## 📍 Verifica que estás en el directorio correcto

Antes de ejecutar, asegúrate de estar en el directorio del repositorio:

```cmd
C:\Users\USER>cd catalogador
C:\Users\USER\catalogador>dir

REM Deberías ver los archivos:
REM - START.bat
REM - LAUNCH_CATALOGADOR.bat
REM - LAUNCH_CATALOGADOR.ps1
REM - etc.
```

## 🎯 Orden Recomendado de Métodos

1. **🥇 Más fácil:** Doble clic en `START.bat` en el Explorador de Windows
2. **🥈 Conveniente:** Crear acceso directo en escritorio con `CREATE_DESKTOP_SHORTCUT.bat`
3. **🥉 Línea de comandos:** Usar CMD con `cd` al directorio y luego `.\START.bat`

## ⚙️ Requisitos Previos

Antes de ejecutar por primera vez, asegúrate de tener instalados:

- ✅ **Python 3.10+** - [Descargar](https://www.python.org/downloads/)
- ✅ **Node.js 18+** - [Descargar](https://nodejs.org/)

El lanzador verificará automáticamente estos requisitos y te avisará si falta algo.

## 🔍 Pasos Completos desde Cero

### Para nuevos usuarios:

1. **Clonar el repositorio:**
   ```cmd
   git clone https://github.com/martinosorio302/catalogador.git
   ```

2. **Entrar al directorio:**
   ```cmd
   cd catalogador
   ```

3. **Iniciar la aplicación:**
   - **Opción A (recomendada):** Abre el Explorador de Windows, navega a la carpeta y haz doble clic en `START.bat`
   - **Opción B:** Desde CMD ejecuta: `.\START.bat`

4. **Esperar:** La primera vez tomará 1-2 minutos mientras instala dependencias

5. **¡Listo!** La aplicación se abrirá automáticamente en tu navegador

## 📋 URLs de Acceso

Una vez iniciada:
- **Interfaz:** http://localhost:5173
- **API:** http://127.0.0.1:8000
- **Docs:** http://127.0.0.1:8000/docs

## 🛑 Detener la Aplicación

Presiona **Ctrl+C** en la ventana de CMD donde se ejecutó el lanzador.

## 💡 Tips Adicionales

### Windows 10/11: Ejecutar desde el menú contextual

1. Shift + Clic derecho en la carpeta `catalogador`
2. Selecciona "Abrir ventana de PowerShell aquí" o "Abrir ventana de comandos aquí"
3. Ejecuta: `.\START.bat`

### PowerShell (alternativa)

Si prefieres PowerShell:
```powershell
cd C:\Users\USER\catalogador
.\LAUNCH_CATALOGADOR.ps1
```

Si aparece error de política de ejecución:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 🐛 Otros Problemas Comunes

### "Python no está instalado"
→ Instala Python 3.10+ y asegúrate de marcar "Add Python to PATH" durante la instalación

### "Node.js no está instalado"
→ Instala Node.js 18+ desde nodejs.org

### "Puerto ya en uso"
→ Cierra otras aplicaciones que usen los puertos 8000 o 5173

### La ventana se cierra inmediatamente
→ Revisa si hay errores. Ejecuta desde CMD para ver los mensajes de error.

---

¿Aún tienes problemas? Revisa [LAUNCHER_README.md](LAUNCHER_README.md) para documentación completa.

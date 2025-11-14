# 🚀 Lanzador de Catalogador EsSalud

Este repositorio incluye scripts de lanzamiento automático para ejecutar la aplicación **Catalogador EsSalud** directamente desde Git como un programa totalmente operativo.

## 📋 Requisitos Previos

Antes de ejecutar la aplicación, asegúrate de tener instalados:

1. **Python 3.10 o superior**
   - Descargar desde: https://www.python.org/downloads/
   - Verificar con: `python --version` o `python3 --version`

2. **Node.js 18 o superior**
   - Descargar desde: https://nodejs.org/
   - Verificar con: `node --version`

3. **Git** (para clonar el repositorio)
   - Descargar desde: https://git-scm.com/

## 🎯 Inicio Rápido

### Windows

#### Opción 1: Ejecutar con doble clic
1. Navega a la carpeta del repositorio
2. **Doble clic** en `LAUNCH_CATALOGADOR.bat`
3. ¡La aplicación se iniciará automáticamente!

#### Opción 2: Ejecutar desde PowerShell
```powershell
cd ruta\al\repositorio\catalogador
.\LAUNCH_CATALOGADOR.ps1
```

#### Opción 3: Ejecutar desde CMD
```cmd
cd ruta\al\repositorio\catalogador
LAUNCH_CATALOGADOR.bat
```

### Linux / macOS

#### Opción 1: Ejecutar desde terminal
```bash
cd /ruta/al/repositorio/catalogador
./LAUNCH_CATALOGADOR.sh
```

#### Opción 2: Dar permisos de ejecución y ejecutar
```bash
chmod +x LAUNCH_CATALOGADOR.sh
./LAUNCH_CATALOGADOR.sh
```

## 🎨 Icono de la Aplicación

El icono de la aplicación se encuentra en:
- **SVG (vectorial)**: `build/icon.svg`

Este icono puede ser usado para:
- Crear accesos directos en el escritorio
- Personalizar lanzadores del sistema
- Integrar con menús de inicio

### Crear un Acceso Directo en Windows

1. Clic derecho en el escritorio → **Nuevo** → **Acceso directo**
2. En ubicación, ingresa:
   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ruta\completa\al\repositorio\LAUNCH_CATALOGADOR.ps1"
   ```
3. Nombre: `Catalogador EsSalud`
4. Clic derecho en el acceso directo → **Propiedades** → **Cambiar icono**
5. Busca el archivo `build\icon.svg` (convertir a .ico con herramientas online si es necesario)

### Crear un Lanzador en Linux (GNOME/KDE)

1. Crear archivo `catalogador.desktop`:
   ```bash
   nano ~/.local/share/applications/catalogador.desktop
   ```

2. Agregar contenido:
   ```ini
   [Desktop Entry]
   Name=Catalogador EsSalud
   Comment=Sistema de catalogación de archivos
   Exec=/ruta/completa/al/repositorio/LAUNCH_CATALOGADOR.sh
   Icon=/ruta/completa/al/repositorio/build/icon.svg
   Terminal=false
   Type=Application
   Categories=Office;Database;
   ```

3. Dar permisos:
   ```bash
   chmod +x ~/.local/share/applications/catalogador.desktop
   ```

## 📖 ¿Qué hace el lanzador?

El script de lanzamiento realiza automáticamente:

1. ✅ **Verifica dependencias**: Python y Node.js
2. ✅ **Crea entorno virtual**: Python venv (si no existe)
3. ✅ **Instala dependencias**: pip install y npm install
4. ✅ **Inicia API Backend**: FastAPI en http://127.0.0.1:8000
5. ✅ **Inicia UI Frontend**: Vite dev server en http://localhost:5173
6. ✅ **Abre navegador**: Automáticamente carga la interfaz
7. ✅ **Muestra logs**: En tiempo real de ambos servicios

## 🌐 URLs de Acceso

Una vez iniciada la aplicación:

- **Interfaz de Usuario**: http://localhost:5173
- **API Backend**: http://127.0.0.1:8000
- **Documentación API**: http://127.0.0.1:8000/docs
- **Health Check**: http://127.0.0.1:8000/health

## 🛑 Detener la Aplicación

Para detener la aplicación de forma segura:

- Presiona **Ctrl+C** en la terminal donde se ejecutó el script
- Los servicios se detendrán automáticamente
- No es necesario matar procesos manualmente

## 🔧 Solución de Problemas

### "Python no está instalado"
- Instala Python 3.10+ desde https://www.python.org
- En Windows, marca "Add Python to PATH" durante la instalación

### "Node.js no está instalado"
- Instala Node.js 18+ desde https://nodejs.org
- Verifica que `node` y `npm` estén en el PATH

### "No se puede ejecutar PowerShell"
- En Windows, ejecuta como Administrador:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Puerto ya en uso
- Si los puertos 8000 o 5173 están ocupados:
  - Cierra otras aplicaciones que usen esos puertos
  - O modifica los puertos en los scripts de lanzamiento

### Dependencias no se instalan
- Elimina las carpetas `.venv` y `src/node_modules`
- Ejecuta el lanzador nuevamente para reinstalar

## 📝 Notas

- **Primera ejecución**: Puede tomar 1-2 minutos instalando dependencias
- **Ejecuciones posteriores**: Inicio inmediato (dependencias ya instaladas)
- **Actualizaciones**: Al hacer `git pull`, las dependencias se actualizan automáticamente
- **Modo desarrollo**: Los archivos se recargan automáticamente al editarlos

## 💡 Tips

1. **Agregar al menú de inicio** (Windows):
   - Copia el acceso directo a `%APPDATA%\Microsoft\Windows\Start Menu\Programs`

2. **Iniciar con el sistema**:
   - Agrega el acceso directo a la carpeta de inicio de Windows
   - O usa servicios del sistema (NSSM, systemd)

3. **Ejecutar en modo producción**:
   - Ver documentación en `README_DEPLOY.md`
   - Usar los scripts en `tools/` para deployment

## 🆘 Soporte

Para problemas o preguntas:
- Revisa la documentación completa en `README.md`
- Consulta los logs en las carpetas `_build_logs/` o `/tmp/`
- Verifica que los requisitos estén cumplidos

---

**¡Disfruta usando Catalogador EsSalud!** 📁✨

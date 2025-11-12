====================================
Catalogador EsSalud - Instalador
====================================

Bienvenido al instalador de Catalogador EsSalud.

REQUISITOS DEL SISTEMA:
-----------------------
- Windows 10/11 (64-bit)
- .NET 8 Desktop Runtime
- Python 3.11 o superior
- 4 GB RAM mínimo
- 1 GB espacio en disco

COMPONENTES A INSTALAR:
-----------------------
1. Aplicación de Escritorio WPF (.NET 8)
   - Interfaz gráfica de usuario
   - Gestión de documentos
   - Visualización TRD
   - Exportación a Excel

2. Servicio Backend (Python FastAPI)
   - API REST en puerto 8000
   - Procesamiento OCR
   - Clasificación de documentos
   - Motor TRD

3. Herramientas de Servicio Windows
   - Scripts de instalación/desinstalación
   - Gestión del servicio

DURANTE LA INSTALACIÓN:
-----------------------
El instalador realizará las siguientes acciones:

1. Copiar archivos de la aplicación
2. Instalar dependencias de Python
3. Configurar el servicio de Windows (si se selecciona)
4. Crear accesos directos

DESPUÉS DE LA INSTALACIÓN:
--------------------------
1. El servicio de backend se iniciará automáticamente
2. La aplicación estará disponible en el Menú Inicio
3. Los logs se guardarán en:
   - Aplicación: %LOCALAPPDATA%\CatalogadorEsSalud\logs\
   - Servicio: [Carpeta de Instalación]\logs\

DESINSTALACIÓN:
---------------
Use el desinstalador desde:
- Panel de Control > Programas > Desinstalar
- O desde el Menú Inicio > Catalogador EsSalud

El desinstalador detendrá y eliminará el servicio automáticamente.

SOPORTE:
--------
Para más información, consulte:
- README.md en la carpeta de instalación
- https://github.com/martinosorio302/catalogador

====================================
Presione "Siguiente" para continuar
====================================

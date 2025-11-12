# Guía de Evaluación y Testing - Catalogador EsSalud

## 📋 Estado de Validación Actual

### ✅ Backend Python - VALIDADO
```
✓ 11/11 tests pasando
✓ API endpoints funcionando
✓ TRD classification operativo
✓ Import/Export funcional
✓ Concurrency handling correcto
```

**Tests ejecutados**:
- `test_health` - Health endpoint ✓
- `test_classify_basic` - Clasificación básica ✓
- `test_write_multiple_atomic_partial_failure` - Escritura atómica ✓
- `test_write_dest_atomic` - Destino de escritura ✓
- `test_concurrent_writes` - Concurrencia ✓
- `test_import_retencion_integration` - Integración import ✓
- `test_reload_requires_token` - Autenticación ✓
- `test_fallback` & `test_sample_match` - TRD engine ✓
- `test_upload_sanitizes_and_limits` - Upload seguro ✓

---

## 🖥️ Evaluación de la Interfaz WPF

### Preparación del Entorno

1. **Actualizar repositorio**:
   ```powershell
   git pull origin copilot/fix-integration-issues-vscode
   ```

2. **Compilar aplicación**:
   ```powershell
   # Opción 1: Build automático (recomendado)
   .\build.bat
   
   # Opción 2: Build manual
   dotnet build Catalogador.sln -c Release
   ```

3. **Verificar compilación**:
   ```powershell
   # Debe existir el ejecutable
   Test-Path ".\Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe"
   ```

---

## 🧪 Plan de Testing - Interfaz WPF

### PASO 1: Verificar Backend

**Objetivo**: Asegurar que el backend Python está corriendo

**Acciones**:
1. Abrir PowerShell como Administrador
2. Navegar a la carpeta del proyecto
3. Iniciar el backend:
   ```powershell
   # Opción A: Servicio Windows (si está instalado)
   .\tools\start_service.ps1
   
   # Opción B: Ejecución directa
   python -m uvicorn api.main:app --reload
   ```

4. Verificar en navegador: http://127.0.0.1:8000/health
   - Debe devolver: `{"status": "ok"}`

**Resultado Esperado**:
```json
{
  "status": "ok"
}
```

---

### PASO 2: Iniciar Aplicación WPF

**Objetivo**: Lanzar la interfaz gráfica

**Acciones**:
1. Ejecutar el programa:
   ```powershell
   .\Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe
   ```

2. Observar la ventana principal

**Resultado Esperado**:
- ✅ Ventana WPF se abre sin errores
- ✅ Se muestra el título "Catalogador EsSalud"
- ✅ Se ven 3 pestañas:
  - "Cargar Documento"
  - "Ver TRD"
  - "Exportar Inventario"

**Capturas a tomar**:
- Screenshot 1: Ventana principal al abrir
- Screenshot 2: Indicador de conexión API (arriba a la derecha)

---

### PASO 3: Probar Conexión API

**Objetivo**: Verificar que la aplicación se conecta al backend

**Acciones**:
1. Observar el indicador de estado en la esquina superior derecha
2. Debe mostrar: "API: Conectado ✓" en verde

**Si muestra "API: Desconectado ✗"**:
- Verificar que el backend está corriendo (Paso 1)
- Revisar logs en: `%LOCALAPPDATA%\CatalogadorEsSalud\logs\`

**Resultado Esperado**:
- ✅ Indicador muestra "API: Conectado ✓"
- ✅ Color verde indica conexión exitosa

**Captura a tomar**:
- Screenshot 3: Indicador de conexión en verde

---

### PASO 4: Probar Carga de Documento

**Objetivo**: Validar la funcionalidad de upload de archivos PDF

**Acciones**:
1. Ir a la pestaña "Cargar Documento"
2. Hacer clic en "Seleccionar archivo PDF"
3. Elegir un archivo PDF de prueba
4. Hacer clic en "Procesar Documento"
5. Observar la barra de progreso y mensajes

**Archivos de Prueba Sugeridos**:
- Cualquier PDF simple (1-2 páginas)
- PDF con texto claro y legible
- Ubicación: Crear carpeta `test_pdfs/` con ejemplos

**Resultado Esperado**:
- ✅ Botón "Seleccionar archivo" funciona
- ✅ Nombre del archivo se muestra
- ✅ Botón "Procesar Documento" se activa
- ✅ Barra de progreso se muestra durante el procesamiento
- ✅ Mensaje de éxito o error aparece

**Posibles Mensajes**:
- ✅ Éxito: "Documento procesado correctamente"
- ⚠️ Error: "Error al procesar el documento: [detalle]"

**Capturas a tomar**:
- Screenshot 4: Pestaña de carga con archivo seleccionado
- Screenshot 5: Barra de progreso procesando
- Screenshot 6: Mensaje de resultado (éxito o error)

---

### PASO 5: Probar Visor de TRD

**Objetivo**: Verificar visualización de Tabla de Retención Documental

**Acciones**:
1. Ir a la pestaña "Ver TRD"
2. Hacer clic en "Cargar TRD"
3. Observar la tabla de datos

**Resultado Esperado**:
- ✅ DataGrid se llena con registros TRD
- ✅ Columnas visibles:
  - Serie
  - Subserie
  - Nombre del Documento
  - Retención (años)
  - Disposición Final

**Datos de Ejemplo Esperados**:
```
Serie: 01
Subserie: 01.01
Nombre: Resoluciones Administrativas
Retención: 10 años
Disposición: Archivo Central
```

**Capturas a tomar**:
- Screenshot 7: Pestaña TRD con datos cargados
- Screenshot 8: Detalles de un registro específico

---

### PASO 6: Probar Exportación de Inventario

**Objetivo**: Validar generación de archivo Excel

**Acciones**:
1. Ir a la pestaña "Exportar Inventario"
2. Hacer clic en "Seleccionar ubicación"
3. Elegir carpeta de destino
4. Hacer clic en "Exportar a Excel"
5. Esperar confirmación
6. Abrir el archivo generado

**Resultado Esperado**:
- ✅ Diálogo de guardado se abre
- ✅ Archivo `.xlsx` se crea
- ✅ Mensaje de éxito: "Inventario exportado correctamente"
- ✅ Archivo Excel contiene:
  - Hoja "Inventario"
  - Columnas: Código, Descripción, Serie, Subserie, Fecha
  - Formato profesional con encabezados

**Verificación del Excel**:
1. Abrir con Microsoft Excel o LibreOffice
2. Verificar que hay datos (si se han procesado documentos)
3. Verificar formato de celdas y encabezados

**Capturas a tomar**:
- Screenshot 9: Pestaña de exportación
- Screenshot 10: Diálogo de guardado
- Screenshot 11: Mensaje de éxito
- Screenshot 12: Archivo Excel abierto

---

### PASO 7: Verificar Logs

**Objetivo**: Revisar que el logging funciona correctamente

**Acciones**:
1. Abrir Explorador de Windows
2. Navegar a: `%LOCALAPPDATA%\CatalogadorEsSalud\logs\`
3. Abrir el archivo de log más reciente

**Resultado Esperado**:
- ✅ Carpeta de logs existe
- ✅ Archivos con formato: `catalogador_YYYYMMDD.log`
- ✅ Contenido incluye:
  - Timestamp de cada operación
  - Conexiones API exitosas
  - Resultados de procesamiento
  - Errores (si los hay)

**Ejemplo de Log**:
```
2025-01-12 10:30:15 [INFO] Aplicación iniciada
2025-01-12 10:30:16 [INFO] Conectado a API en http://127.0.0.1:8000
2025-01-12 10:32:45 [INFO] Archivo seleccionado: documento.pdf
2025-01-12 10:32:47 [INFO] Procesamiento iniciado
2025-01-12 10:32:52 [INFO] Documento procesado correctamente
```

**Captura a tomar**:
- Screenshot 13: Carpeta de logs
- Screenshot 14: Contenido de archivo log

---

## 📊 Checklist de Evaluación

### Funcionalidad del Backend
- [ ] Backend inicia sin errores
- [ ] Endpoint /health responde correctamente
- [ ] 11/11 tests Python pasan
- [ ] API acepta peticiones HTTP

### Interfaz WPF
- [ ] Aplicación inicia correctamente
- [ ] Ventana principal se muestra
- [ ] 3 pestañas están visibles y funcionales
- [ ] Indicador de conexión API funciona

### Carga de Documentos
- [ ] Botón "Seleccionar archivo" funciona
- [ ] Diálogo de apertura de archivos se muestra
- [ ] Nombre de archivo seleccionado aparece
- [ ] Botón "Procesar" se activa correctamente
- [ ] Barra de progreso funciona
- [ ] Mensajes de éxito/error se muestran

### Visor TRD
- [ ] Botón "Cargar TRD" funciona
- [ ] DataGrid se llena con datos
- [ ] Columnas se muestran correctamente
- [ ] Datos TRD son legibles

### Exportación
- [ ] Botón "Seleccionar ubicación" funciona
- [ ] Diálogo de guardado se abre
- [ ] Archivo Excel se genera
- [ ] Excel contiene datos correctos
- [ ] Formato Excel es profesional

### Logging y Errores
- [ ] Carpeta de logs se crea
- [ ] Archivos de log se generan
- [ ] Logs contienen información útil
- [ ] Errores se capturan y registran
- [ ] Mensajes de error son claros

---

## 🐛 Problemas Comunes y Soluciones

### Problema 1: "API: Desconectado"

**Causa**: Backend no está corriendo

**Solución**:
```powershell
# Iniciar backend manualmente
python -m uvicorn api.main:app --reload

# O instalar/iniciar servicio
.\tools\install_windows_service.ps1
.\tools\start_service.ps1
```

### Problema 2: Aplicación no inicia

**Causa**: .NET 8 Desktop Runtime no instalado

**Solución**:
1. Descargar: https://dotnet.microsoft.com/download/dotnet/8.0
2. Instalar ".NET Desktop Runtime 8.0.x"
3. Reiniciar aplicación

### Problema 3: Error al procesar PDF

**Causa**: PDF corrupto o sin permisos

**Solución**:
- Usar un PDF simple y válido
- Verificar que el archivo no esté bloqueado
- Revisar logs en `%LOCALAPPDATA%\CatalogadorEsSalud\logs\`

### Problema 4: Excel no se genera

**Causa**: Permisos de escritura o carpeta no válida

**Solución**:
- Elegir carpeta con permisos de escritura
- Ejemplo: `C:\Users\TuUsuario\Documents\`
- Verificar espacio en disco

### Problema 5: Datos TRD vacíos

**Causa**: Base de datos TRD no cargada

**Solución**:
- Verificar archivo `engine/trd.py`
- Confirmar que `TRD_DATA` tiene registros
- Revisar logs del backend

---

## 📸 Documentación de Resultados

### Screenshots Requeridos

Por favor, tomar las siguientes capturas durante las pruebas:

1. **Screenshot 1**: Ventana principal al iniciar
2. **Screenshot 2**: Indicador de conexión API
3. **Screenshot 3**: Conexión exitosa (verde)
4. **Screenshot 4**: Archivo PDF seleccionado
5. **Screenshot 5**: Procesamiento en curso (barra de progreso)
6. **Screenshot 6**: Mensaje de resultado
7. **Screenshot 7**: Visor TRD con datos
8. **Screenshot 8**: Detalle de registro TRD
9. **Screenshot 9**: Pestaña de exportación
10. **Screenshot 10**: Diálogo de guardado Excel
11. **Screenshot 11**: Mensaje de éxito exportación
12. **Screenshot 12**: Archivo Excel abierto
13. **Screenshot 13**: Carpeta de logs
14. **Screenshot 14**: Contenido de log

### Formato de Reporte

```markdown
# Reporte de Evaluación - Catalogador EsSalud

## Información del Sistema
- OS: Windows 10/11
- .NET Version: 8.0.x
- Python Version: 3.11.x
- Fecha: YYYY-MM-DD

## Resultados de Pruebas

### Backend
- Estado: ✅ Funcional / ❌ Error
- Tests: 11/11 passing
- API Health: ✅ OK
- Notas: [comentarios]

### Interfaz WPF
- Inicio: ✅ / ❌
- Conexión API: ✅ / ❌
- Carga Documento: ✅ / ❌
- Visor TRD: ✅ / ❌
- Exportación Excel: ✅ / ❌
- Logs: ✅ / ❌

### Problemas Encontrados
1. [Descripción del problema]
   - Screenshot: [número]
   - Solución intentada: [descripción]
   - Resultado: ✅ / ❌

### Conclusión
[Resumen general del estado de la aplicación]
```

---

## 🎯 Criterios de Éxito

La aplicación se considera **funcional y lista para producción** si:

✅ **Backend (5/5)**:
- [ ] Inicia sin errores
- [ ] Health endpoint responde
- [ ] Tests pasan
- [ ] Acepta peticiones de WPF
- [ ] Logs se generan correctamente

✅ **WPF (6/6)**:
- [ ] Aplicación inicia
- [ ] Interfaz es responsiva
- [ ] Conexión API funciona
- [ ] Carga de archivos funciona
- [ ] Visualización de datos funciona
- [ ] Exportación funciona

✅ **Calidad (4/4)**:
- [ ] No hay excepciones no manejadas
- [ ] Mensajes de error son claros
- [ ] Logs son informativos
- [ ] UI es intuitiva

**Total: 15/15 criterios cumplidos = APROBADO**

---

## 📞 Siguiente Paso

Después de completar estas pruebas, responder con:

1. ✅ Número de screenshots tomados
2. ✅ Checklist de evaluación completada
3. ✅ Lista de problemas encontrados (si hay)
4. ✅ Conclusión: ¿La aplicación funciona correctamente?

**Ejemplo de respuesta**:
```
Evaluación completada:
- 14/14 screenshots tomados ✅
- 15/15 criterios cumplidos ✅
- 0 problemas críticos encontrados
- Conclusión: Aplicación funcional y lista para producción
```

---

**Última actualización**: 2025-01-12  
**Versión de la aplicación**: 1.0.0  
**Estado del repositorio**: Commit 9d5fc3b9

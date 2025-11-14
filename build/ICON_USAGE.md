# 🎨 Icono de Catalogador EsSalud

## Vista del Icono

El icono de la aplicación (`icon.svg`) presenta:

- **Fondo azul** (#2563eb) con esquinas redondeadas
- **Carpeta de archivos** en tonos azules claros
- **Documento** blanco en el centro con líneas que representan texto
- **Texto "Catalogador"** en blanco, bold
- **Texto "EsSalud"** en azul claro debajo

## Características

- **Formato**: SVG (Scalable Vector Graphics)
- **Dimensiones**: 256x256px (escalable sin pérdida de calidad)
- **Colores**: Paleta azul profesional de la identidad EsSalud
- **Diseño**: Minimalista y moderno

## Usos del Icono

### 1. Accesos Directos de Escritorio
El icono se puede usar para crear accesos directos personalizados en:
- Windows (convertir a .ico)
- Linux (usar .svg directamente)
- macOS (convertir a .icns)

### 2. Integración con Sistema Operativo
- Menú de inicio de Windows
- Dock de macOS
- Lanzadores de aplicaciones en Linux (GNOME, KDE, etc.)

### 3. Documentación y Marketing
- Documentación del proyecto
- Presentaciones
- Material promocional

## Conversión a Otros Formatos

### Convertir SVG a ICO (Windows)
```bash
# Usando ImageMagick
convert icon.svg -define icon:auto-resize=256,128,64,48,32,16 icon.ico

# Online: https://convertio.co/svg-ico/
```

### Convertir SVG a ICNS (macOS)
```bash
# Crear iconset
mkdir icon.iconset
convert icon.svg -resize 16x16 icon.iconset/icon_16x16.png
convert icon.svg -resize 32x32 icon.iconset/icon_16x16@2x.png
convert icon.svg -resize 32x32 icon.iconset/icon_32x32.png
convert icon.svg -resize 64x64 icon.iconset/icon_32x32@2x.png
convert icon.svg -resize 128x128 icon.iconset/icon_128x128.png
convert icon.svg -resize 256x256 icon.iconset/icon_128x128@2x.png
convert icon.svg -resize 256x256 icon.iconset/icon_256x256.png
convert icon.svg -resize 512x512 icon.iconset/icon_256x256@2x.png
convert icon.svg -resize 512x512 icon.iconset/icon_512x512.png
convert icon.svg -resize 1024x1024 icon.iconset/icon_512x512@2x.png

# Crear icns
iconutil -c icns icon.iconset
```

### Convertir SVG a PNG (múltiples tamaños)
```bash
# Usando ImageMagick o Inkscape
convert icon.svg -resize 512x512 icon-512.png
convert icon.svg -resize 256x256 icon-256.png
convert icon.svg -resize 128x128 icon-128.png
convert icon.svg -resize 64x64 icon-64.png
convert icon.svg -resize 32x32 icon-32.png
convert icon.svg -resize 16x16 icon-16.png
```

## Paleta de Colores

| Color | Hex | Uso |
|-------|-----|-----|
| Azul primario | #2563eb | Fondo principal |
| Azul claro 1 | #60a5fa | Parte superior de carpeta |
| Azul claro 2 | #93c5fd | Cuerpo de carpeta |
| Blanco | #ffffff | Documento y texto principal |
| Azul muy claro | #dbeafe | Texto secundario |

## Ejemplos de Uso

### En README.md
```markdown
![Catalogador Icon](build/icon.svg)
```

### En HTML
```html
<img src="build/icon.svg" width="64" height="64" alt="Catalogador">
```

### En Acceso Directo de Windows
1. Convertir a .ico
2. Clic derecho en acceso directo → Propiedades
3. Cambiar icono → Buscar icon.ico

### En .desktop Linux
```ini
[Desktop Entry]
Name=Catalogador EsSalud
Icon=/ruta/completa/a/catalogador/build/icon.svg
```

## Recursos Útiles

- **Herramientas online**:
  - [CloudConvert](https://cloudconvert.com/) - Conversión de formatos
  - [Convertio](https://convertio.co/) - SVG a ICO/PNG
  - [RealFaviconGenerator](https://realfavicongenerator.net/) - Favicons

- **Herramientas de línea de comandos**:
  - ImageMagick: `apt-get install imagemagick` (Linux) / `brew install imagemagick` (Mac)
  - Inkscape: Para conversiones de alta calidad

## Licencia

Este icono es parte del proyecto Catalogador EsSalud y está sujeto a la misma licencia del proyecto.

#!/bin/bash
# ============================================================================
# Catalogador EsSalud - Launcher Script (Bash)
# ============================================================================
# Este script lanza la aplicación completa desde el repositorio Git
# Ejecuta el backend API y el frontend UI automáticamente
# ============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   📁 Catalogador EsSalud - Lanzador de Aplicación        ║"
echo "║   Iniciando backend API y frontend UI...                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Obtener la ruta del repositorio
REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$REPO_ROOT"

# Verificar que Python está instalado
echo -e "${YELLOW}🔍 Verificando Python...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo -e "${RED}❌ ERROR: Python no está instalado${NC}"
    echo -e "${RED}   Por favor instala Python 3.10+ desde https://www.python.org${NC}"
    exit 1
fi
echo -e "${GREEN}   ✓ Python encontrado: $($PYTHON_CMD --version)${NC}"

# Verificar que Node.js está instalado
echo -e "${YELLOW}🔍 Verificando Node.js...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ ERROR: Node.js no está instalado${NC}"
    echo -e "${RED}   Por favor instala Node.js 18+ desde https://nodejs.org${NC}"
    exit 1
fi
echo -e "${GREEN}   ✓ Node.js encontrado: $(node --version)${NC}"

# Crear y activar entorno virtual Python si no existe
echo -e "${YELLOW}📦 Verificando dependencias Python...${NC}"
if [ ! -d ".venv" ]; then
    echo -e "${CYAN}   Creando entorno virtual Python...${NC}"
    $PYTHON_CMD -m venv .venv
fi

# Activar entorno virtual
if [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
fi

echo -e "${CYAN}   Instalando dependencias Python...${NC}"
$PYTHON_CMD -m pip install -q --upgrade pip
$PYTHON_CMD -m pip install -q -r requirements.txt
$PYTHON_CMD -m pip install -q -e .
echo -e "${GREEN}   ✓ Dependencias Python instaladas${NC}"

# Verificar/instalar dependencias Node.js
echo -e "${YELLOW}📦 Verificando dependencias Node.js...${NC}"
cd "$REPO_ROOT/src"
if [ ! -d "node_modules" ]; then
    echo -e "${CYAN}   Instalando dependencias Node.js...${NC}"
    npm install --silent
    echo -e "${GREEN}   ✓ Dependencias Node.js instaladas${NC}"
else
    echo -e "${GREEN}   ✓ Dependencias Node.js ya instaladas${NC}"
fi
cd "$REPO_ROOT"

# Crear archivos PID para tracking
API_PID_FILE="/tmp/catalogador_api.pid"
UI_PID_FILE="/tmp/catalogador_ui.pid"

# Función de limpieza
cleanup() {
    echo -e "\n${YELLOW}🛑 Deteniendo servicios...${NC}"
    
    if [ -f "$API_PID_FILE" ]; then
        API_PID=$(cat "$API_PID_FILE")
        if ps -p $API_PID > /dev/null 2>&1; then
            kill $API_PID 2>/dev/null || true
        fi
        rm -f "$API_PID_FILE"
    fi
    
    if [ -f "$UI_PID_FILE" ]; then
        UI_PID=$(cat "$UI_PID_FILE")
        if ps -p $UI_PID > /dev/null 2>&1; then
            kill $UI_PID 2>/dev/null || true
        fi
        rm -f "$UI_PID_FILE"
    fi
    
    # Kill any remaining processes
    pkill -f "uvicorn api.main:app" 2>/dev/null || true
    pkill -f "vite" 2>/dev/null || true
    
    echo -e "${GREEN}   ✓ Servicios detenidos${NC}"
}

# Registrar cleanup al recibir señal de salida
trap cleanup EXIT INT TERM

# Iniciar API backend en background
echo -e "${YELLOW}🚀 Iniciando API backend en http://127.0.0.1:8000 ...${NC}"
cd "$REPO_ROOT"
$PYTHON_CMD -m uvicorn api.main:app --host 127.0.0.1 --port 8000 --reload > /tmp/catalogador_api.log 2>&1 &
echo $! > "$API_PID_FILE"
sleep 3
echo -e "${GREEN}   ✓ API backend iniciado (PID: $(cat $API_PID_FILE))${NC}"

# Iniciar UI frontend en background
echo -e "${YELLOW}🚀 Iniciando UI frontend en http://localhost:5173 ...${NC}"
cd "$REPO_ROOT/src"
npm run dev > /tmp/catalogador_ui.log 2>&1 &
echo $! > "$UI_PID_FILE"
sleep 5
echo -e "${GREEN}   ✓ UI frontend iniciado (PID: $(cat $UI_PID_FILE))${NC}"

cd "$REPO_ROOT"

echo ""
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   ✅ Catalogador EsSalud está ejecutándose!              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${CYAN}📍 API Backend:  http://127.0.0.1:8000${NC}"
echo -e "${CYAN}📍 UI Frontend:  http://localhost:5173${NC}"
echo -e "${CYAN}📖 API Docs:     http://127.0.0.1:8000/docs${NC}"
echo ""
echo -e "${YELLOW}⚠️  Para detener la aplicación, presiona Ctrl+C${NC}"
echo ""

# Abrir navegador (dependiendo del OS)
echo -e "${YELLOW}🌐 Abriendo navegador...${NC}"
sleep 2
if command -v xdg-open &> /dev/null; then
    xdg-open "http://localhost:5173" &>/dev/null &
elif command -v open &> /dev/null; then
    open "http://localhost:5173" &>/dev/null &
elif command -v start &> /dev/null; then
    start "http://localhost:5173" &>/dev/null &
fi

# Mostrar logs
echo -e "${CYAN}📋 Mostrando logs (presiona Ctrl+C para salir):${NC}"
echo "─────────────────────────────────────────────────────────────"

# Seguir logs de ambos servicios
tail -f /tmp/catalogador_api.log /tmp/catalogador_ui.log 2>/dev/null &
TAIL_PID=$!

# Esperar indefinidamente (hasta Ctrl+C)
wait $TAIL_PID

# Cleanup se ejecutará automáticamente por el trap
echo ""
echo -e "${CYAN}👋 Catalogador EsSalud cerrado. ¡Hasta pronto!${NC}"

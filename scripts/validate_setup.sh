#!/bin/bash
# Validation script for Catalogador development environment setup
# Usage: bash scripts/validate_setup.sh

set -e

echo "======================================"
echo "Catalogador Setup Validation Script"
echo "======================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

validate() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
        exit 1
    fi
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check Python version
echo "Checking Python..."
python3 --version > /dev/null 2>&1
validate "Python 3 is installed"

# Check Python version is 3.11 or higher
PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
if [ "$(echo "$PYTHON_VERSION >= 3.11" | bc 2>/dev/null || echo "0")" = "1" ] || [[ "$PYTHON_VERSION" == "3.11"* ]] || [[ "$PYTHON_VERSION" == "3.12"* ]]; then
    validate "Python version is 3.11+ ($PYTHON_VERSION)"
else
    warn "Python version $PYTHON_VERSION - recommended: 3.11+"
fi

# Check Node.js
echo ""
echo "Checking Node.js..."
node --version > /dev/null 2>&1
validate "Node.js is installed"

NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -ge 18 ]; then
    validate "Node.js version is 18+ (v$NODE_VERSION)"
else
    warn "Node.js version $NODE_VERSION - recommended: 18+"
fi

# Check npm
npm --version > /dev/null 2>&1
validate "npm is installed"

# Check Git
echo ""
echo "Checking Git..."
git --version > /dev/null 2>&1
validate "Git is installed"

# Check Git LFS
git lfs version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    validate "Git LFS is installed"
else
    warn "Git LFS not found - required for large files"
fi

# Check virtual environment
echo ""
echo "Checking Python virtual environment..."
if [ -d ".venv" ]; then
    validate ".venv directory exists"
    
    # Check if venv has Python
    if [ -f ".venv/bin/python" ] || [ -f ".venv/Scripts/python.exe" ]; then
        validate "Virtual environment is properly configured"
    else
        warn "Virtual environment may not be properly initialized"
    fi
else
    warn ".venv directory not found - run: python3 -m venv .venv"
fi

# Check VSCode configuration
echo ""
echo "Checking VSCode configuration..."
if [ -d ".vscode" ]; then
    validate ".vscode directory exists"
    
    [ -f ".vscode/settings.json" ] && validate "settings.json exists" || warn "settings.json not found"
    [ -f ".vscode/tasks.json" ] && validate "tasks.json exists" || warn "tasks.json not found"
    [ -f ".vscode/launch.json" ] && validate "launch.json exists" || warn "launch.json not found"
    [ -f ".vscode/extensions.json" ] && validate "extensions.json exists" || warn "extensions.json not found"
else
    echo -e "${RED}✗${NC} .vscode directory not found"
    exit 1
fi

# Check configuration files
echo ""
echo "Checking configuration files..."
[ -f "mypy.ini" ] && validate "mypy.ini exists" || warn "mypy.ini not found"
[ -f "pyproject.toml" ] && validate "pyproject.toml exists" || warn "pyproject.toml not found"
[ -f "pytest.ini" ] && validate "pytest.ini exists" || warn "pytest.ini not found"

# Check documentation
echo ""
echo "Checking documentation..."
[ -f "VSCODE_SETUP.md" ] && validate "VSCODE_SETUP.md exists" || warn "VSCODE_SETUP.md not found"
[ -f "SOLUTION_SUMMARY.md" ] && validate "SOLUTION_SUMMARY.md exists" || warn "SOLUTION_SUMMARY.md not found"
[ -f "README.md" ] && validate "README.md exists" || warn "README.md not found"

# Check dependencies
echo ""
echo "Checking Python dependencies..."
[ -f "requirements.txt" ] && validate "requirements.txt exists" || warn "requirements.txt not found"
[ -f "dev-requirements.txt" ] && validate "dev-requirements.txt exists" || warn "dev-requirements.txt not found"

echo ""
echo "Checking NPM dependencies..."
[ -f "package.json" ] && validate "package.json exists" || warn "package.json not found"
[ -f "package-lock.json" ] && validate "package-lock.json exists" || warn "package-lock.json not found"
[ -d "node_modules" ] && validate "node_modules exists" || warn "node_modules not found - run: npm install"

echo ""
echo "Checking frontend dependencies..."
[ -f "frontend/package.json" ] && validate "frontend/package.json exists" || warn "frontend/package.json not found"
[ -d "frontend/node_modules" ] && validate "frontend/node_modules exists" || warn "frontend/node_modules not found - run: cd frontend && npm install"

echo ""
echo "Checking src dependencies..."
[ -f "src/package.json" ] && validate "src/package.json exists" || warn "src/package.json not found"
[ -d "src/node_modules" ] && validate "src/node_modules exists" || warn "src/node_modules not found - run: cd src && npm install"

# Summary
echo ""
echo "======================================"
echo -e "${GREEN}✓ Validation Complete!${NC}"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Open in VSCode: code ."
echo "  2. Install recommended extensions (automatic prompt)"
echo "  3. Activate venv: source .venv/bin/activate (Linux/Mac) or .venv\\Scripts\\Activate.ps1 (Windows)"
echo "  4. Install Python dependencies: pip install -r requirements.txt -r dev-requirements.txt && pip install -e ."
echo "  5. Run tests: python -m pytest -v"
echo ""
echo "For detailed setup instructions, see VSCODE_SETUP.md"
echo ""

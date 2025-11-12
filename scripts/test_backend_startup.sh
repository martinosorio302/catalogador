#!/bin/bash
# Quick Backend Validation Script
# Tests if the FastAPI backend can start successfully

set -e

echo "======================================"
echo "Backend Validation Script"
echo "======================================"
echo ""

# Check if we're in the right directory
if [ ! -f "api/main.py" ]; then
    echo "❌ Error: api/main.py not found. Run this from repository root."
    exit 1
fi

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found"
    exit 1
fi
echo "✓ Python 3 found"

# Check if venv needs to be created
if [ ! -d ".test_venv" ]; then
    echo "Creating test virtual environment..."
    python3 -m venv .test_venv
fi

# Activate venv
source .test_venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -q --upgrade pip
pip install -q -r requirements.txt
pip install -q -e .

# Test import
echo "Testing API import..."
python -c "import api.main; print('✓ API module imports successfully')"

# Test basic startup (timeout after 5 seconds)
echo "Testing backend startup..."
timeout 5 python -m uvicorn api.main:app --host 127.0.0.1 --port 8765 &
PID=$!
sleep 3

# Check if process is running
if ps -p $PID > /dev/null; then
    echo "✓ Backend started successfully"
    
    # Try to hit health endpoint
    if command -v curl &> /dev/null; then
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8765/health 2>/dev/null || echo "000")
        if [ "$RESPONSE" = "200" ]; then
            echo "✓ Health endpoint responding (HTTP 200)"
        else
            echo "⚠ Health endpoint returned HTTP $RESPONSE"
        fi
    fi
    
    # Kill the server
    kill $PID 2>/dev/null || true
    wait $PID 2>/dev/null || true
    echo "✓ Backend stopped cleanly"
else
    echo "❌ Backend failed to start"
    deactivate
    exit 1
fi

# Cleanup
deactivate
rm -rf .test_venv

echo ""
echo "======================================"
echo "✓ Backend Validation Complete"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Create production venv: python -m venv .venv"
echo "  2. Install dependencies: pip install -r requirements.txt -e ."
echo "  3. Start server: uvicorn api.main:app --host 127.0.0.1 --port 8000 --reload"
echo ""

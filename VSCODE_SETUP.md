# VSCode Integration Guide for Catalogador

This guide explains how to set up and use Visual Studio Code for developing the Catalogador project.

## Prerequisites

1. **Visual Studio Code** - Download from https://code.visualstudio.com/
2. **Python 3.11 or 3.12** - Required for backend development
3. **Node.js 18+** - Required for frontend/Electron development
4. **Git** - For version control

## Initial Setup

### 1. Install Recommended Extensions

When you open the project in VSCode, you'll be prompted to install recommended extensions. Click "Install All" or install them manually:

**Python Development:**
- Python (Microsoft)
- Pylance (Microsoft)
- Ruff (charliermarsh.ruff)

**JavaScript/TypeScript Development:**
- ESLint (dbaeumer.vscode-eslint)
- Prettier (esbenp.prettier-vscode)
- Tailwind CSS IntelliSense (bradlc.vscode-tailwindcss)
- ES7+ React/Redux/React-Native snippets

**General:**
- GitLens (eamodio.gitlens)
- EditorConfig (editorconfig.editorconfig)

### 2. Set Up Python Environment

#### Windows (PowerShell):
```powershell
# Create virtual environment
python -m venv .venv

# Activate it
.\.venv\Scripts\Activate.ps1

# Install dependencies
python -m pip install --upgrade pip
pip install -r requirements.txt
pip install -r dev-requirements.txt
pip install -e .
```

#### Linux/macOS:
```bash
# Create virtual environment
python3 -m venv .venv

# Activate it
source .venv/bin/activate

# Install dependencies
python -m pip install --upgrade pip
pip install -r requirements.txt
pip install -r dev-requirements.txt
pip install -e .
```

### 3. Set Up Node.js Dependencies

The project has multiple package.json files in different directories:

```bash
# Install root dependencies (for Electron builds)
npm install

# Install frontend dependencies
cd frontend
npm install
cd ..

# Install src dependencies
cd src
npm install
cd ..
```

## Using VSCode Features

### Running Tasks

Press `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (macOS) and type "Tasks: Run Task" to access:

**Python Tasks:**
- `Python: Install Dependencies` - Install Python packages
- `Python: Run Tests` - Run pytest test suite
- `Python: Run Ruff (Lint)` - Run linter
- `Python: Run MyPy (Type Check)` - Run type checker
- `API: Start Development Server` - Start FastAPI server

**Frontend Tasks:**
- `Frontend: Start Dev Server` - Start Vite dev server for frontend/
- `Src: Start Dev Server` - Start Vite dev server for src/
- `Frontend: Build` - Build production frontend
- `Src: Build` - Build production src

**Electron Tasks:**
- `Electron: Dev Mode` - Run Electron in development mode
- `Electron: Build` - Build Electron installer

**Quick Setup:**
- `Full Build: Install All Dependencies` - Install everything at once

### Debugging

The project includes several debug configurations accessible via the Debug panel (Ctrl+Shift+D):

**Python Debugging:**
- `Python: FastAPI Debug` - Debug the API server with breakpoints
- `Python: Current File` - Debug the currently open Python file
- `Python: Run Tests` - Debug a specific test file
- `Python: Run All Tests` - Debug all tests

**Frontend Debugging:**
- `Frontend: Chrome Debug` - Debug frontend in Chrome
- `Src: Chrome Debug` - Debug src in Chrome

**Electron Debugging:**
- `Electron: Main Process` - Debug Electron main process

**Compound Configurations:**
- `Full Stack: API + Frontend` - Debug API and frontend simultaneously

### Testing

#### Python Tests:
- Click the test icon in the left sidebar
- Or use Command Palette: "Python: Run All Tests"
- Or use terminal: `python -m pytest -v`

#### Running Specific Tests:
Open a test file and click the green play button next to test functions.

### Linting and Formatting

**Auto-formatting on save is enabled by default:**
- Python files: Formatted with Ruff
- JavaScript/TypeScript: Formatted with Prettier

**Manual linting:**
- Python: Run the "Python: Run Ruff (Lint)" task
- TypeScript: Run the "Python: Run MyPy (Type Check)" task

### Code Navigation

- `F12` - Go to definition
- `Alt+F12` - Peek definition
- `Shift+F12` - Find all references
- `Ctrl+P` - Quick file open
- `Ctrl+Shift+O` - Go to symbol in file
- `Ctrl+T` - Go to symbol in workspace

### Terminal Integration

VSCode is configured to use PowerShell on Windows by default. Access terminal with:
- `Ctrl+\`` - Toggle integrated terminal

The virtual environment will automatically activate when you open a new terminal.

## Project Structure

```
catalogador/
├── .vscode/              # VSCode configuration
│   ├── settings.json     # Editor settings
│   ├── tasks.json        # Task definitions
│   ├── launch.json       # Debug configurations
│   └── extensions.json   # Recommended extensions
├── api/                  # FastAPI backend
├── frontend/             # React frontend (one variant)
├── src/                  # React frontend (another variant)
├── electron/             # Electron main process
├── tests/                # Python test suite
├── engine/               # Core engine code
├── tools/                # Deployment scripts
└── requirements*.txt     # Python dependencies
```

## Multi-Root Workspace Notes

This project has multiple frontend directories (`frontend/` and `src/`). Both contain Vite + React applications:
- Use the appropriate task or debug configuration for the one you're working on
- Linting is configured to work in both directories

## Troubleshooting

### Python Interpreter Not Found
1. Press `Ctrl+Shift+P`
2. Type "Python: Select Interpreter"
3. Choose `.venv/Scripts/python.exe` (or `.venv/bin/python` on Unix)

### Import Errors in Python
1. Ensure you've run `pip install -e .` to install the package in editable mode
2. Check that PYTHONPATH includes the workspace folder

### Node Modules Missing
Run `npm install` in the root directory and in `frontend/` and `src/` directories.

### Tasks Don't Work on Linux/macOS
Edit `.vscode/tasks.json` to use Unix-style paths:
- Replace `${workspaceFolder}/.venv/Scripts/python.exe` 
- With `${workspaceFolder}/.venv/bin/python`

### Vite Version Conflicts
If you see version warnings, run:
```bash
npm install vite@5.4.10 --save-dev
```

## Development Workflow

### Typical Development Session:

1. **Open VSCode in project root**
2. **Activate Python environment** (automatic in integrated terminal)
3. **Start backend API:**
   - Run task: "API: Start Development Server"
   - Or terminal: `python -m uvicorn api.main:app --reload --host 127.0.0.1 --port 8000`
4. **Start frontend:**
   - Run task: "Frontend: Start Dev Server" or "Src: Start Dev Server"
   - Or terminal: `cd frontend && npm run dev`
5. **Make changes and test**
6. **Run tests before committing:**
   - Python: Run task "Python: Run Tests"
   - Or terminal: `python -m pytest -v`

### CI/CD Integration

The project includes GitHub Actions CI/CD in `.github/workflows/ci.yml`:
- Runs on push/PR to main/master branches
- Tests on Ubuntu and Windows with Python 3.11 and 3.12
- Runs linting (ruff), type checking (mypy), and tests (pytest)

Your local VSCode setup matches the CI environment, so tests that pass locally should pass in CI.

## Additional Resources

- [Python in VSCode](https://code.visualstudio.com/docs/python/python-tutorial)
- [JavaScript in VSCode](https://code.visualstudio.com/docs/languages/javascript)
- [Debugging in VSCode](https://code.visualstudio.com/docs/editor/debugging)
- [Tasks in VSCode](https://code.visualstudio.com/docs/editor/tasks)

## Getting Help

If you encounter issues:
1. Check this guide's troubleshooting section
2. Review the main README.md for project-specific setup
3. Check `.vscode/` configuration files for task/debug settings
4. Consult the VSCode documentation

## Quick Reference Commands

```bash
# Python
python -m pytest -v                    # Run all tests
python -m pytest tests/test_file.py    # Run specific test
python -m ruff check .                 # Lint code
python -m mypy .                       # Type check
python -m uvicorn api.main:app --reload  # Start API

# Node/NPM
npm install                            # Install dependencies
npm run dev                            # Start dev server
npm run build                          # Build for production

# Git
git status                             # Check status
git add .                              # Stage changes
git commit -m "message"                # Commit
git push                               # Push to remote
```

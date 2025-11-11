#!/bin/bash
# Remove Duplicate Implementations - Architectural Consolidation
# This script removes Electron/React frontends, .NET backend, and old bundles
# Per confirmed architectural decision: Keep Python API + WPF frontend only

set -e

echo "=========================================="
echo "Catalogador - Remove Duplicate Implementations"
echo "=========================================="
echo ""

# Directories to remove
DIRS_TO_REMOVE=(
    "frontend"           # Electron/React frontend (replaced by WPF)
    "src"                # Alternate Electron frontend
    "electron"           # Electron main process
    "backend"            # .NET API backend (replaced by Python)
    "pr_bundle"          # Old code bundle
    "pr_bundle_v2"       # Old code bundle v2
    "app-desktop"        # Duplicate WPF app location (consolidated)
    "dist"               # Vite build output
    "dist-electron"      # Electron build output
)

echo "The following directories will be PERMANENTLY REMOVED:"
echo ""
for dir in "${DIRS_TO_REMOVE[@]}"; do
    if [ -d "$dir" ]; then
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1)
        echo "  - $dir ($SIZE)"
    else
        echo "  - $dir (not found)"
    fi
done

echo ""
echo "Total space to be freed: ~504 MB"
echo ""
echo "Note: Git history will preserve these files if needed for recovery"
echo ""

read -p "Continue with removal? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Removal cancelled."
    exit 0
fi

echo ""
echo "Removing directories..."
echo ""

# Remove each directory
for dir in "${DIRS_TO_REMOVE[@]}"; do
    if [ -d "$dir" ]; then
        echo "  Removing $dir..."
        rm -rf "$dir"
        echo "    ✓ Removed"
    else
        echo "  Skipping $dir (not found)"
    fi
done

echo ""
echo "=========================================="
echo "Removal Complete"
echo "=========================================="
echo ""
echo "Removed:"
for dir in "${DIRS_TO_REMOVE[@]}"; do
    echo "  - $dir"
done
echo ""
echo "Next steps:"
echo "  1. Update .gitignore"
echo "  2. Remove Electron dependencies from package.json"
echo "  3. Update documentation"
echo "  4. Commit changes"
echo ""

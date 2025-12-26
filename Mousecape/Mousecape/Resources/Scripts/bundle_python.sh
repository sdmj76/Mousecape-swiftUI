#!/bin/bash
#
# bundle_python.sh
# Bundles Python + Pillow into Mousecape.app for Windows cursor import
#
# This script is called during the build phase for the Mousecape-Dev scheme.
# It creates a minimal Python virtual environment with Pillow installed.
#

set -e

# Configuration
PYTHON_VERSION="python3"
VENV_NAME="python-env"
APP_RESOURCES="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources"
VENV_PATH="${APP_RESOURCES}/${VENV_NAME}"
SCRIPTS_SRC="${SRCROOT}/Mousecape/Resources/Scripts"

echo "=== Bundling Python Environment ==="

# Check if Python is available
if ! command -v ${PYTHON_VERSION} &> /dev/null; then
    echo "Error: ${PYTHON_VERSION} not found"
    exit 1
fi

# Remove existing venv if present
if [ -d "${VENV_PATH}" ]; then
    echo "Removing existing Python environment..."
    rm -rf "${VENV_PATH}"
fi

# Create virtual environment
echo "Creating virtual environment..."
${PYTHON_VERSION} -m venv "${VENV_PATH}"

# Activate and install Pillow
echo "Installing Pillow..."
source "${VENV_PATH}/bin/activate"
pip install --upgrade pip --quiet
pip install Pillow --quiet
deactivate

# Copy conversion script
echo "Copying cursor conversion script..."
cp "${SCRIPTS_SRC}/curconvert.py" "${APP_RESOURCES}/"
chmod +x "${APP_RESOURCES}/curconvert.py"

# Create a wrapper script for easy invocation
# Note: We directly call the bundled Python instead of using activate script
# because activate contains hardcoded paths that break when app is relocated
cat > "${APP_RESOURCES}/run_curconvert.sh" << 'EOF'
#!/bin/bash
# Wrapper script to run curconvert.py with bundled Python
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_BIN="${SCRIPT_DIR}/python-env/bin/python3"

# Use bundled Python directly (avoids hardcoded paths in activate script)
"${PYTHON_BIN}" "${SCRIPT_DIR}/curconvert.py" "$@"
EOF
chmod +x "${APP_RESOURCES}/run_curconvert.sh"

# Calculate size
VENV_SIZE=$(du -sh "${VENV_PATH}" | cut -f1)
echo "=== Python Environment Bundled ==="
echo "Location: ${VENV_PATH}"
echo "Size: ${VENV_SIZE}"
echo "Done!"

#!/usr/bin/env bash
# Compiles and installs the wineUIPC bridge for X-Plane 12
#
# Prerequisites:
#   - X-Plane 12 installed
#   - XPPython3 installed in X-Plane
#   - mingw-w64 cross-compiler (for building the bridge .exe)
#     On NixOS: nix-shell -p pkgsCross.mingwW64.buildPackages.gcc
#
# Usage: ./setup-wineuipc.sh [XPLANE_DIR]
#   Default XPLANE_DIR is ~/X-Plane 12

set -euo pipefail

XPLANE_DIR="${1:-$HOME/X-Plane 12}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(dirname "$SCRIPT_DIR")"
WINEUIPC_DIR="$WORK_DIR/wineUIPC"

echo "=== wineUIPC Bridge Setup ==="
echo "X-Plane dir: $XPLANE_DIR"
echo ""

# Check X-Plane exists
if [ ! -f "$XPLANE_DIR/X-Plane-x86_64" ]; then
    echo "ERROR: X-Plane not found at $XPLANE_DIR"
    echo "Usage: $0 [XPLANE_DIR]"
    exit 1
fi

# Check XPPython3 is installed
if [ ! -d "$XPLANE_DIR/Resources/plugins/XPPython3" ]; then
    echo "ERROR: XPPython3 not found in X-Plane plugins."
    echo "Download from: https://xppython3.readthedocs.io/"
    echo "Extract to: $XPLANE_DIR/Resources/plugins/XPPython3/"
    exit 1
fi

# Check mingw compiler
if ! command -v x86_64-w64-mingw32-gcc &>/dev/null; then
    echo "ERROR: mingw-w64 cross-compiler not found."
    echo "On NixOS, run this script inside: nix-shell -p pkgsCross.mingwW64.buildPackages.gcc"
    exit 1
fi

# Clone wineUIPC if not already present
if [ ! -d "$WINEUIPC_DIR" ]; then
    echo "[1/3] Cloning wineUIPC..."
    git clone https://github.com/clumsynick/wineUIPC.git "$WINEUIPC_DIR"
else
    echo "[1/3] wineUIPC already cloned at $WINEUIPC_DIR"
fi

# Compile bridge
echo ""
echo "[2/3] Compiling uipc_bridge.exe..."
x86_64-w64-mingw32-gcc -O2 "$WINEUIPC_DIR/uipc_bridge.c" -lws2_32 -lgdi32 -o "$WINEUIPC_DIR/uipc_bridge.exe"
echo "Built: $WINEUIPC_DIR/uipc_bridge.exe"

# Install plugin into X-Plane
echo ""
echo "[3/3] Installing wineUIPC plugin into X-Plane..."
PLUGINS_DIR="$XPLANE_DIR/Resources/plugins/PythonPlugins"
mkdir -p "$PLUGINS_DIR/wineUIPC"
cp "$WINEUIPC_DIR/PI_wineUIPC.py" "$PLUGINS_DIR/"
cp "$WINEUIPC_DIR/wineUIPC/main.py" "$PLUGINS_DIR/wineUIPC/"
echo "Installed to: $PLUGINS_DIR"

echo ""
echo "=== wineUIPC setup complete! ==="
echo ""
echo "To use:"
echo "  1. Start X-Plane 12"
echo "  2. Wait for XPPython3 to load (check XPPython3Log.txt)"
echo "  3. Start bridge: wine $WINEUIPC_DIR/uipc_bridge.exe"
echo ""

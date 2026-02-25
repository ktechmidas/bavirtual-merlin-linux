#!/usr/bin/env bash
# Starts the full BAVirtual Merlin + X-Plane stack on Linux
#
# This launches:
#   1. X-Plane 12 (native, optionally with NVIDIA offload)
#   2. wineUIPC bridge (under Wine)
#   3. BAVirtual Merlin (under Wine)
#
# Usage:
#   ./start-merlin-stack.sh              # start everything
#   ./start-merlin-stack.sh --no-xplane  # start bridge + Merlin only (X-Plane already running)
#   ./start-merlin-stack.sh --nvidia     # use NVIDIA GPU for X-Plane
#
# Environment variables:
#   XPLANE_DIR    - X-Plane install path (default: ~/X-Plane 12)
#   WINEPREFIX    - Wine prefix path (default: ~/.wine)
#   WINEUIPC_DIR  - wineUIPC directory (default: auto-detect from script location)

set -euo pipefail

# Defaults
XPLANE_DIR="${XPLANE_DIR:-$HOME/X-Plane 12}"
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WINEUIPC_DIR="${WINEUIPC_DIR:-$(dirname "$SCRIPT_DIR")/wineUIPC}"
MERLIN_EXE="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Programs/BAVirtual Merlin/BAV Merlin.exe"
BRIDGE_EXE="$WINEUIPC_DIR/uipc_bridge.exe"

START_XPLANE=true
USE_NVIDIA=false

# Parse args
for arg in "$@"; do
    case $arg in
        --no-xplane) START_XPLANE=false ;;
        --nvidia)    USE_NVIDIA=true ;;
        --help|-h)
            echo "Usage: $0 [--no-xplane] [--nvidia]"
            echo "  --no-xplane  Skip starting X-Plane (if already running)"
            echo "  --nvidia     Use NVIDIA GPU via nvidia-offload"
            exit 0
            ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# Validate files exist
if [ ! -f "$BRIDGE_EXE" ]; then
    echo "ERROR: wineUIPC bridge not found at $BRIDGE_EXE"
    echo "Run setup-wineuipc.sh first."
    exit 1
fi

if [ ! -f "$MERLIN_EXE" ]; then
    echo "ERROR: Merlin not found at $MERLIN_EXE"
    echo "Install Merlin first: wine BAV_Merlin_Installer.exe"
    exit 1
fi

echo "=== BAVirtual Merlin Stack ==="
echo "X-Plane:  $XPLANE_DIR"
echo "Bridge:   $BRIDGE_EXE"
echo "Merlin:   $MERLIN_EXE"
echo "Prefix:   $WINEPREFIX"
echo ""

# Cleanup on exit
PIDS=()
cleanup() {
    echo ""
    echo "Shutting down..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
    echo "Done."
}
trap cleanup EXIT INT TERM

# 1. Start X-Plane
if [ "$START_XPLANE" = true ]; then
    echo "[1/3] Starting X-Plane 12..."
    if [ "$USE_NVIDIA" = true ]; then
        # NixOS: uses xplane-run FHS wrapper + nvidia-offload
        if command -v xplane-run &>/dev/null; then
            xplane-run nvidia-offload "$XPLANE_DIR/X-Plane-x86_64" &
        else
            # Non-NixOS: try direct nvidia-offload or env vars
            if command -v nvidia-offload &>/dev/null; then
                nvidia-offload "$XPLANE_DIR/X-Plane-x86_64" &
            else
                __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia "$XPLANE_DIR/X-Plane-x86_64" &
            fi
        fi
    else
        if command -v xplane-run &>/dev/null; then
            xplane-run "$XPLANE_DIR/X-Plane-x86_64" &
        else
            "$XPLANE_DIR/X-Plane-x86_64" &
        fi
    fi
    PIDS+=($!)

    echo "Waiting for X-Plane to start (30 seconds)..."
    sleep 30
else
    echo "[1/3] Skipping X-Plane (--no-xplane)"
fi

# 2. Start wineUIPC bridge
echo ""
echo "[2/3] Starting wineUIPC bridge..."
wine "$BRIDGE_EXE" &
PIDS+=($!)
sleep 3

# 3. Start Merlin
echo ""
echo "[3/3] Starting BAVirtual Merlin..."
wine "$MERLIN_EXE" &
PIDS+=($!)

echo ""
echo "=== All components running ==="
echo "Press Ctrl+C to shut down everything."
echo ""

# Wait for any process to exit
wait -n "${PIDS[@]}" 2>/dev/null || true

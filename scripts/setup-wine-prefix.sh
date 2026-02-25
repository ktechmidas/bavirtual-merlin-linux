#!/usr/bin/env bash
# Sets up a Wine prefix for BAVirtual Merlin
#
# Prerequisites: wine and winetricks must be installed
# On NixOS: add wineWowPackages.stable and winetricks to environment.systemPackages
#
# This script will:
#   1. Create a fresh 64-bit Wine prefix
#   2. Set Windows version to Windows 10
#   3. Install .NET Framework 4.8 (required - Wine Mono does NOT work)
#   4. Install core Windows fonts
#
# Usage: ./setup-wine-prefix.sh [WINEPREFIX]
#   Default WINEPREFIX is ~/.wine

set -euo pipefail

PREFIX="${1:-$HOME/.wine}"
export WINEPREFIX="$PREFIX"
export WINEARCH=win64

echo "=== BAVirtual Merlin Wine Prefix Setup ==="
echo "Prefix: $WINEPREFIX"
echo ""

# Check prerequisites
if ! command -v wine &>/dev/null; then
    echo "ERROR: wine is not installed."
    echo "On NixOS, add wineWowPackages.stable to environment.systemPackages"
    exit 1
fi

if ! command -v winetricks &>/dev/null; then
    echo "ERROR: winetricks is not installed."
    echo "On NixOS, add winetricks to environment.systemPackages"
    exit 1
fi

# Warn if prefix already exists
if [ -d "$WINEPREFIX" ]; then
    echo "WARNING: Wine prefix already exists at $WINEPREFIX"
    read -rp "Delete and recreate? (y/N) " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -rf "$WINEPREFIX"
    else
        echo "Aborting."
        exit 1
    fi
fi

echo ""
echo "[1/4] Initializing 64-bit Wine prefix..."
wineboot --init 2>&1 | tail -5
echo "Done."

echo ""
echo "[2/4] Setting Windows version to Windows 10..."
echo "  (Merlin installer requires Win10+)"
winetricks -q win10
echo "Done."

echo ""
echo "[3/4] Installing .NET Framework 4.8..."
echo "  (This takes a while - several GUI prompts may appear, click through them)"
echo "  IMPORTANT: Wine Mono does NOT work with Merlin (causes font crashes)."
echo "  .NET 4.8 will replace Wine Mono automatically."
winetricks -q dotnet48
echo "Done."

echo ""
echo "[4/4] Installing core Windows fonts..."
winetricks -q corefonts
echo "Done."

echo ""
echo "=== Wine prefix setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Download Merlin installer from BAVirtual (requires membership)"
echo "  2. Run: wine BAV_Merlin_Installer.exe"
echo "  3. Click through the installer GUI"
echo ""

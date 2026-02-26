# BAVirtual Merlin on Linux

Running BAVirtual's Merlin ACARS client on Linux with X-Plane 12.

> First achieved 2026-02-25. As far as we can tell, nobody had publicly done this before.

## Architecture

```
X-Plane 12 (native Linux)
    |
    v
wineUIPC XPPython3 plugin (native, inside X-Plane)
    | (TCP/JSON on localhost)
    v
uipc_bridge.exe (Wine)
    | (shared memory / WM_COPYDATA)
    v
BAV Merlin.exe (Wine, same prefix)
    | (HTTPS)
    v
BAVirtual servers
```

Merlin communicates with the sim via FSUIPC shared memory. Since X-Plane runs natively on Linux, [wineUIPC](https://github.com/clumsynick/wineUIPC) acts as the bridge: its XPPython3 plugin reads X-Plane datarefs and sends them over TCP to a small Windows executable (`uipc_bridge.exe`) running under Wine, which exposes them as FSUIPC shared memory that Merlin can read.

Merlin identifies the simulator via FSUIPC handshake offsets. The wineUIPC plugin must be configured to report as X-Plane/XPUIPC (not MSFS) for Merlin to correctly match aircraft.

## Quick Start

**Prerequisites:** Wine, winetricks, X-Plane 12, BAVirtual membership (for Merlin installer), mingw-w64 cross-compiler (for building the bridge).

```bash
# 1. Set up Wine prefix
./scripts/setup-wine-prefix.sh

# 2. Install Merlin (download installer from BAVirtual first)
wine BAV_Merlin_Installer.exe

# 3. Set up wineUIPC bridge (requires XPPython3 in X-Plane)
./scripts/setup-wineuipc.sh

# 4. Launch everything
./scripts/start-merlin-stack.sh --nvidia    # with NVIDIA GPU
./scripts/start-merlin-stack.sh             # without NVIDIA offload
./scripts/start-merlin-stack.sh --no-xplane # if X-Plane is already running
```

Or do it manually — see the detailed guide below.

## Repository Contents

```
bavirtual-merlin-linux/
├── RESEARCH.md              # This file
├── nix/
│   ├── xplane.nix           # NixOS FHS wrapper for X-Plane 12 (all required libraries)
│   └── nvidia-prime.nix     # NixOS NVIDIA PRIME offload config (hybrid GPU laptops)
├── scripts/
│   ├── setup-wine-prefix.sh # Automated Wine prefix setup (win10 + .NET 4.8 + fonts)
│   ├── setup-wineuipc.sh    # Clone, compile, and install wineUIPC bridge
│   └── start-merlin-stack.sh # Launch X-Plane + bridge + Merlin in one command
└── installer/               # Place BAV_Merlin_Installer.exe here
```

---

## Detailed Setup Guide

### Step 1: Install Wine and winetricks

**NixOS:**
Add to `configuration.nix` systemPackages and rebuild:
```nix
wineWowPackages.stable  # Wine 11.0 (64+32 bit)
winetricks
```
Note: on nixos-unstable, Wine builds from source (~35 minutes). It may be in the binary cache on stable.

**Ubuntu/Debian:**
```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install wine64 wine32 winetricks
```

**Fedora:**
```bash
sudo dnf install wine winetricks
```

**Arch:**
```bash
sudo pacman -S wine winetricks
```

### Step 2: Set up Wine prefix

Run the automated script or do it manually. **Order matters.**

```bash
# Automated:
./scripts/setup-wine-prefix.sh

# Manual:
export WINEARCH=win64
wineboot --init
winetricks win10       # MUST be done before .NET install
winetricks dotnet48    # Real .NET 4.8 — Wine Mono does NOT work
winetricks corefonts
```

**Why not Wine Mono?** Merlin uses DevComponents.DotNetBar2 for UI rendering. Under Wine Mono, this crashes with a `System.Drawing.FontFamily` disposed object error when loading icon fonts. Real .NET 4.8 works perfectly.

### Step 3: Install Merlin

Download the installer from BAVirtual (requires membership): https://github.com/bavirtual/merlin

```bash
wine BAV_Merlin_Installer.exe
```

Click through the GUI. Installs to:
```
~/.wine/drive_c/users/$USER/AppData/Local/Programs/BAVirtual Merlin/
```

### Step 4: Get X-Plane 12 running

X-Plane 12 has a native Linux build. On most distros it runs directly. On NixOS, you need an FHS wrapper because X-Plane expects a traditional filesystem layout.

**NixOS:** Copy `nix/xplane.nix` into your NixOS config directory, import it from `configuration.nix`, and rebuild. Then launch X-Plane with:
```bash
xplane-run ~/X-Plane\ 12/X-Plane-x86_64
```

**Other distros:** Just run the binary directly:
```bash
~/X-Plane\ 12/X-Plane-x86_64
```

If you get missing library errors, install them via your package manager. Common ones needed: `libcups2`, `libnss3`, `libgbm1`, `libbsd0`.

### Step 5: NVIDIA PRIME offload (hybrid GPU laptops only)

If you have an AMD/Intel iGPU + NVIDIA dGPU, X-Plane will default to the weak integrated GPU and be extremely laggy.

**NixOS:** Copy `nix/nvidia-prime.nix` into your config, update the bus IDs for your hardware, import and rebuild. Then launch with:
```bash
xplane-run nvidia-offload ~/X-Plane\ 12/X-Plane-x86_64
```

Find your bus IDs:
```bash
lspci | grep -E "VGA|3D"
# Example output:
# 01:00.0 3D controller: NVIDIA Corporation GA104M [GeForce RTX 3080 Mobile]  -> PCI:1:0:0
# 06:00.0 VGA compatible controller: AMD/ATI Cezanne                          -> PCI:6:0:0
```

**Other distros:** Use `prime-run`, `nvidia-offload`, or set environment variables:
```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia ~/X-Plane\ 12/X-Plane-x86_64
```

### Step 6: Install XPPython3

XPPython3 is a plugin framework that lets X-Plane run Python plugins. The wineUIPC bridge needs it.

1. Download from https://xppython3.readthedocs.io/ (get the version matching your Python)
2. Extract into `~/X-Plane 12/Resources/plugins/XPPython3/`
3. Start X-Plane — XPPython3 will auto-install dependencies (numpy, pillow, etc.)
4. Check `~/X-Plane 12/XPPython3Log.txt` to verify it loaded

### Step 7: Install wineUIPC bridge

Run the automated script or do it manually:

```bash
# Automated (requires mingw cross-compiler):
./scripts/setup-wineuipc.sh

# Manual:
git clone https://github.com/clumsynick/wineUIPC.git
cd wineUIPC
x86_64-w64-mingw32-gcc -O2 uipc_bridge.c -lws2_32 -lgdi32 -o uipc_bridge.exe

# Install the XPPython3 plugin
cp PI_wineUIPC.py ~/X-Plane\ 12/Resources/plugins/PythonPlugins/
mkdir -p ~/X-Plane\ 12/Resources/plugins/PythonPlugins/wineUIPC/
cp wineUIPC/main.py ~/X-Plane\ 12/Resources/plugins/PythonPlugins/wineUIPC/
```

**mingw cross-compiler:**
- NixOS: `nix-shell -p pkgsCross.mingwW64.buildPackages.gcc`
- Ubuntu/Debian: `sudo apt install gcc-mingw-w64-x86-64`
- Fedora: `sudo dnf install mingw64-gcc`
- Arch: `sudo pacman -S mingw-w64-gcc`

### Step 7b: Configure wineUIPC for X-Plane

The wineUIPC plugin defaults to identifying as MSFS2024, but **Merlin requires the X-Plane/XPUIPC identity** to correctly match aircraft. Edit the config file:

```
~/X-Plane 12/Resources/plugins/PythonPlugins/wineUIPC/wineUIPC.cfg
```

Set these values:
```ini
log_level=2
host=127.0.0.1
port=9000
fs_version=8
fsuipc_version=5.000
fsuipc_build_letter=h
fsairlines_compat=0
```

Key settings:
- `fs_version=8` — tells Merlin this is X-Plane (14 = MSFS2024, 8 = X-Plane)
- `fsuipc_version=5.000` with `fsuipc_build_letter=h` — matches what real XPUIPC reports on Windows

You can verify the identity by checking Merlin's log after connecting:
```
~/.wine/drive_c/users/$USER/AppData/Roaming/BAV_ACARS/UnsupportedSims.log
```
It should show `Resolved Version: X-Plane` and `IsXPlane: True`.

### Step 7c: Set up aircraft folder naming

BAVirtual's server-side matching expects specific aircraft folder names. If your aircraft folder doesn't match, Merlin won't recognise the airframe.

**Required folder names** (case-sensitive, in `~/X-Plane 12/Aircraft/`):
- ToLiss A320neo → `ToLissA320N`
- ToLiss A321neo → `ToLissA321N`
- ToLiss A340-600 → `ToLissA340`
- FlightFactor A320 → `FlightFactorA320`
- FlightFactor 757 → `FF757v2`
- FlightFactor 767 → `FF767`

If your folder has a different name (e.g. `ToLissA320_V1p2p1`), rename it:
```bash
cd ~/X-Plane\ 12/Aircraft/
mv ToLissA320_V1p2p1 ToLissA320N
```

See the [BAVirtual forum post](https://forum.bavirtual.co.uk/forums/topic/2415-my-toliss-or-flightfactor-aircraft-isnt-recognized-by-merlin-what-can-i-do/) for the complete list.

### Step 8: Launch the full stack

Use the convenience script:
```bash
./scripts/start-merlin-stack.sh --nvidia     # launch everything with NVIDIA GPU
./scripts/start-merlin-stack.sh --no-xplane  # X-Plane already running
```

Or launch each component manually:
```bash
# 1. Start X-Plane (NixOS with NVIDIA)
xplane-run nvidia-offload ~/X-Plane\ 12/X-Plane-x86_64 &

# 2. Wait for X-Plane to fully load, then start the bridge
wine /path/to/wineUIPC/uipc_bridge.exe &

# 3. Start Merlin (MUST launch from install dir!)
cd ~/.wine/drive_c/users/$USER/AppData/Local/Programs/BAVirtual\ Merlin/
wine "./BAV Merlin.exe" &
```

Merlin should detect the simulator and show a connection.

**Important: Restart Merlin after first connection.** On the very first connection, Merlin receives Unix-style paths (e.g. `/home/user/X-Plane 12/...`) instead of Windows paths. This confuses the aircraft matching. Simply close and restart Merlin — on the second launch it works correctly. This is a one-time issue per session.

---

## Aircraft Identification

Merlin verifies that you're flying the correct aircraft and livery for your booked flight. It reads aircraft data from FSUIPC shared memory offsets, which wineUIPC populates from X-Plane datarefs.

### How it works

The wineUIPC plugin reads these X-Plane datarefs every flight loop tick:

| Dataref | Example Value |
|---------|---------------|
| `sim/aircraft/view/acf_ICAO` | `A20N` |
| `sim/aircraft/view/acf_descrip` | `A320 with high fidelity system modelling` |
| `sim/aircraft/view/acf_tailnum` | `G-TTND` |
| `sim/aircraft/view/acf_relative_path` | `Aircraft/ToLissA320N/a320.acf` |
| `sim/aircraft/view/acf_livery_path` | `Aircraft/ToLissA320N/liveries/British Airways (G-TTND)/` |
| `sim/system/directory_path` | `/home/user/X-Plane 12/` |

These are then mapped to FSUIPC offsets:

| Offset | Size | FSUIPC Field | Source |
|--------|------|-------------|--------|
| 0x3D00 | 256 | Aircraft title | `<folder> <livery>` e.g. `ToLissA320N British Airways (G-TTND)` |
| 0x3C00 | 256 | Air file path | `acf_relative_path` |
| 0x3E00 | 256 | Sim install path | `sim/system/directory_path` |
| 0x3500 | 24 | ATC model | `acf_ICAO` e.g. `A20N` |
| 0x3148 | 24 | ATC airline | Extracted from livery name e.g. `British Airways` |
| 0x313C | 12 | ATC tail number | `acf_tailnum` e.g. `G-TTND` |
| 0x3160 | 24 | ATC type | Folder name e.g. `ToLissA320N` |

The **aircraft title at 0x3D00 is the key field** that Merlin uses for matching. It's constructed as `<FolderName> <LiveryName>` — the folder name comes from `acf_relative_path` and the livery name comes from the last component of `acf_livery_path`.

### Matching process

Merlin downloads pattern databases from the BAVirtual server (`Known_title_match`, `Known_path_match`, `Known_airline_match`). These contain regex-like patterns that match against the FSUIPC offset data. The matching is entirely server-side — no aircraft names are hardcoded in the Merlin binary.

For X-Plane, the title match patterns look for the folder name (e.g. `ToLissA320N`) combined with airline/livery keywords (e.g. `British Airways`).

### Debugging aircraft detection

1. Check `wineUIPC.log` for `AIRCRAFT` lines showing what data is being sent
2. Check `UnsupportedSims.log` to verify `IsXPlane: True`
3. Ensure the aircraft folder name matches BAVirtual's expected format (see Step 7c)
4. Ensure your livery folder is named with the airline name (most liveries already are)

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Merlin crashes with `FontFamily` / `ObjectDisposedException` | Running on Wine Mono instead of .NET 4.8 | Delete prefix, recreate with `winetricks dotnet48` |
| Installer says "This version of Windows is not supported" | Wine version set below Windows 10 | Run `winetricks win10` first |
| Merlin says "airport database deploy file missing" | Merlin resolves DB_DEPLOY relative to the **working directory**, not the exe path | Always `cd` to the install directory before launching: `cd ~/.wine/.../BAVirtual\ Merlin/ && wine "./BAV Merlin.exe"` |
| X-Plane missing shared libraries (NixOS) | FHS wrapper missing packages | Run `xplane-run ldd X-Plane-x86_64` and add missing libs to `xplane.nix` |
| X-Plane extremely laggy | Running on integrated GPU | Configure NVIDIA PRIME offload, launch with `nvidia-offload` |
| XPPython3 doesn't load | Missing `libbsd.so.0` or similar | Add `libbsd` to FHS wrapper / install via package manager |
| Wine "fixme:" messages in terminal | Normal Wine debug output | Harmless, ignore them. Suppress with `WINEDEBUG=-all` |
| Merlin shows "MSFS2024" as sim | wineUIPC.cfg still has `fs_version=14` | Change to `fs_version=8`, `fsuipc_version=5.000`, `fsuipc_build_letter=h` (see Step 7b) |
| Merlin doesn't detect aircraft/livery | Wrong folder name, wrong sim version, or first-run path issue | Check folder naming (Step 7c), verify `IsXPlane: True` in `UnsupportedSims.log`, restart Merlin once |
| Aircraft detected on second launch only | First connection sends Unix paths | Normal — restart Merlin after first connection. Works correctly from second launch onward |
| Bridge won't connect | X-Plane not running or plugin not loaded | Check `XPPython3Log.txt` for wineUIPC plugin loading |

---

## About Merlin

BAVirtual's proprietary ACARS client. Members-only, free, closed-source.

- **Latest version**: v1.19.0723 (29 July 2025)
- **Repo** (installer only): https://github.com/bavirtual/merlin
- **Supported sims**: FS2004, FSX, Prepar3D, MSFS 2020, X-Plane
- **Officially supported OS**: Windows 10, Windows 11

### Tech stack (confirmed by binary inspection)

- VB.NET WinForms (NOT WPF — this is why it works well under Wine)
- .NET Framework 4.8
- Assembly version: 1.19.5.23
- UI: Bunifu_UI_v1.52, DevComponents.DotNetBar2 v14.0.0.3
- Sim communication: FSUIPCClient.dll
- Data serialization: Newtonsoft.Json, protobuf-net

### How Merlin works

1. Book a flight through BAVMS (BAVirtual Management System)
2. Load flight into Merlin, enter OFP details
3. Merlin verifies correct airframe and livery
4. Tracks from pushback to gate arrival and power down
5. Auto-files PIREP to logbook (no manual PIREPs accepted)
6. POSREP every ~60 min (solve a math problem or tune COM2) - prevents AFK flying
7. Off-duty mode available for long-haul (5+ hours)

## About wineUIPC

An open-source bridge that lets FSUIPC-dependent Windows apps communicate with X-Plane running natively on Linux.

- **Repo**: https://github.com/clumsynick/wineUIPC
- **X-Plane.org**: https://forums.x-plane.org/files/file/97513-wineuipc-bridge-fsuipcxpuipc-under-linux/
- **Status**: Alpha (v0.1.0-alpha.8, January 2026)
- **Tested with**: A Pilot's Life 2, FSAirlines, and now BAVirtual Merlin

Two components:
1. **XPPython3 plugin** — runs natively inside X-Plane, reads datarefs and maps them to FSUIPC offsets
2. **uipc_bridge.exe** — runs under Wine, exposes FSUIPC shared memory interface via WM_COPYDATA

They communicate over TCP with a JSON protocol. Either side can restart independently.

**Offset coverage**: position, attitude, flight controls, engines (1-4), systems, lights, performance, environment, weight/fuel, NAV/ADF/DME, time, frame rate, autopilot, aircraft identification (title, path, ICAO, airline, tail number).

---

## Testing Status

- [x] Wine prefix setup (.NET 4.8, corefonts, win10)
- [x] Merlin installs and launches
- [x] wineUIPC bridge compiles and runs
- [x] XPPython3 + wineUIPC plugin loads in X-Plane
- [x] Merlin detects simulator through bridge
- [x] Aircraft identification working (folder name + livery matching)
- [x] wineUIPC configured for X-Plane/XPUIPC identity (fs_version=8)
- [x] Complete a full test flight (ACARS tracking end-to-end) — first PIREP filed from Linux!
- [ ] Verify all FSUIPC offsets Merlin needs are covered by wineUIPC

## Tested Environment

| Component | Version |
|-----------|---------|
| OS | NixOS (nixos-unstable), kernel 6.18.12 |
| Wine | 11.0 (wineWowPackages.stable) |
| .NET | Framework 4.8 (via winetricks) |
| X-Plane | 12 (native Linux) |
| XPPython3 | 4.6.1 |
| wineUIPC | 0.1.0-alpha.8 |
| Merlin | 1.19.0723 |
| GPU | NVIDIA RTX 3080 Mobile (PRIME offload) |

## References

- https://github.com/bavirtual/merlin
- https://www.bavirtual.co.uk/resources-tools/
- https://github.com/clumsynick/wineUIPC
- https://forums.x-plane.org/files/file/97513-wineuipc-bridge-fsuipcxpuipc-under-linux/
- https://xppython3.readthedocs.io/
- https://flightsimonlinux.com
- https://github.com/smyalygames/flightsim-on-linux
- https://forum.bavirtual.co.uk/forums/topic/2415-my-toliss-or-flightfactor-aircraft-isnt-recognized-by-merlin-what-can-i-do/

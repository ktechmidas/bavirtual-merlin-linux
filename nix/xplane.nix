# X-Plane 12 FHS environment wrapper for NixOS
#
# X-Plane 12 is a dynamically-linked Linux binary that expects a traditional
# FHS filesystem layout. NixOS doesn't have one, so we use buildFHSEnv to
# create a wrapper that provides all required shared libraries.
#
# Usage:
#   xplane-run ~/X-Plane\ 12/X-Plane-x86_64           # run on integrated GPU
#   xplane-run nvidia-offload ~/X-Plane\ 12/X-Plane-x86_64  # run on NVIDIA dGPU
#   xplane-run                                          # drop into FHS shell for debugging
#
# Import this file from your configuration.nix:
#   imports = [ ./xplane.nix ];

{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.buildFHSEnv {
      name = "xplane-run";
      targetPkgs = pkgs: with pkgs; [
        # Core
        stdenv.cc.cc.lib
        zlib
        glib
        gtk3
        pango
        cairo
        gdk-pixbuf
        atk
        harfbuzz
        dbus

        # Graphics
        libGL
        libGLU
        vulkan-loader
        libx11
        libxext
        libxrandr
        libxcursor
        libxi
        libxinerama
        libxscrnsaver
        libxxf86vm

        # Audio
        alsa-lib
        libpulseaudio

        # X11 extras
        libxcomposite
        libxdamage
        libxfixes
        libxcb
        libxkbcommon
        xorg.libXt

        # System
        cups.lib
        libdrm
        mesa
        mesa.drivers
        libgbm
        expat

        # Network / misc
        curl
        openssl
        freetype
        fontconfig
        cacert
        nss
        nspr
        libbsd

        # WebKit (needed by X-Plane installer/updater UI)
        webkitgtk_4_1
        libsoup_3
        gst_all_1.gstreamer
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-good
      ];
      runScript = pkgs.writeShellScript "xplane-run-init" ''
        if [ $# -eq 0 ]; then
          exec bash
        else
          exec "$@"
        fi
      '';
    })
  ];
}

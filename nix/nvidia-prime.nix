# NVIDIA PRIME offload configuration for hybrid GPU laptops (AMD iGPU + NVIDIA dGPU)
#
# Without this, X-Plane will run on the integrated GPU and be extremely laggy.
# After applying, use `nvidia-offload <command>` to run apps on the NVIDIA GPU.
#
# Find your bus IDs with:
#   lspci | grep -E "VGA|3D"
# Convert hex to decimal (e.g. 06:00.0 -> PCI:6:0:0, 01:00.0 -> PCI:1:0:0)
#
# Import this file from your configuration.nix:
#   imports = [ ./nvidia-prime.nix ];

{ ... }:

{
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;  # provides nvidia-offload command
      };
      # CHANGE THESE to match your hardware!
      amdgpuBusId = "PCI:6:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}

{ inputs, ... }:

let
  inherit (inputs) nixos-hardware;
in
{
  imports = [
    "${nixos-hardware}/common/cpu/intel"
    "${nixos-hardware}/common/gpu/nvidia/prime.nix"
    "${nixos-hardware}/common/gpu/nvidia/ada-lovelace"
    "${nixos-hardware}/common/pc/laptop"
    "${nixos-hardware}/common/pc/ssd"
    "${nixos-hardware}/asus/battery.nix"
  ];

  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";

    offload.enable = false;
    sync.enable = true;
  };
}

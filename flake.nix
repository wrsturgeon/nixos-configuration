{
  inputs = {
    aider-src = {
      flake = false;
      url = "github:aider-ai/aider";
    };
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:hyprwm/hyprland";
    };
    kicad-src = {
      flake = false;
      url = "git+https://gitlab.com/kicad/code/kicad.git?ref=9.0";
    };
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvim-aider-src = {
      flake = false;
      url = "github:georgesalkhouri/nvim-aider";
    };
    ollama-src = {
      flake = false;
      url = "github:ollama/ollama/v0.9.3";
    };
    rust-overlay.url = "github:oxalica/rust-overlay";
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
    zen-browser = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:0xc000022070/zen-browser-flake";
    };
  };
  outputs =
    inputs@{
      flake-utils,
      nixpkgs,
      self,
      treefmt-nix,
      ...
    }:
    let
      inherit (self) outputs;
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;
          enable-hyprland = false;
          ollama-default-model = "gemma3n:e4b";
          username = "will";
        };
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix # from the automated hardware scan: don't edit!
          ./home-manager.nix
          ./nixos-hardware.nix
          inputs.home-manager.nixosModules.home-manager
          inputs.nixvim.nixosModules.nixvim
        ];
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        treefmt = treefmt-nix.lib.evalModule pkgs ./.treefmt.nix;
      in
      {
        formatter = treefmt.config.build.wrapper;

        apps =
          builtins.mapAttrs
            (k: v: {
              program = "${pkgs.writeScriptBin k v}/bin/${k}";
              type = "app";
            })
            {
              default = ''
                #!${pkgs.bash}/bin/bash
                set -euxo pipefail
                shopt -s nullglob

                echo '{' > ./cores.nix
                echo "  available = $(nproc --all 2>/dev/null);" >> ./cores.nix
                echo '  total = rec {' >> ./cores.nix
                echo "    threads-per-core = $(lscpu | grep 'Thread(s) per core:' | rev | cut -d ' ' -f 1 | rev);" >> ./cores.nix
                echo "    cores-per-socket = $(lscpu | grep 'Core(s) per socket:' | rev | cut -d ' ' -f 1 | rev);" >> ./cores.nix
                echo "    sockets = $(lscpu | grep 'Socket(s):' | rev | cut -d ' ' -f 1 | rev);" >> ./cores.nix
                echo "    physical = cores-per-socket * sockets;" >> ./cores.nix
                echo "    threads-total = threads-per-core * physical;" >> ./cores.nix
                echo '  };' >> ./cores.nix
                echo '}' >> ./cores.nix
              '';
            };
      }
    );
}

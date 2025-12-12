{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils?shallow=1";
    google-fonts = {
      flake = false;
      url = "github:google/fonts/main?shallow=1";
    };
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager/master?shallow=1";
    };
    hyprland = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:hyprwm/hyprland/main?shallow=1";
    };
    iosevka = {
      flake = false;
      url = "github:be5invis/iosevka/main?shallow=1";
    };
    kicad-src = {
      flake = false;
      url = "git+https://gitlab.com/kicad/code/kicad.git?ref=9.0&shallow=1";
    };
    linux = {
      flake = false;
      url = "github:torvalds/linux/master?shallow=1";
    };
    morphcloud = {
      flake = false;
      url = "github:morph-labs/morph-python-sdk/main?shallow=1";
    };
    nix-darwin = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-darwin/nix-darwin/master?shallow=1";
    };
    nixos-hardware.url = "github:nixos/nixos-hardware/master?shallow=1";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable?shallow=1";
    # nixpkgs.url = "github:nixos/nixpkgs/master?shallow=1";
    nixvim = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/nixvim/main?shallow=1";
    };
    rust-overlay = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:oxalica/rust-overlay/master?shallow=1";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix/main?shallow=1";
    };
    zen-browser = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:0xc000022070/zen-browser-flake/main?shallow=1";
    };
  };
  outputs =
    inputs@{
      flake-utils,
      nix-darwin,
      nixpkgs,
      self,
      treefmt-nix,
      ...
    }:
    let
      inherit (self) outputs;

      specialArgs = {
        inherit
          inputs
          nh-clean-all-flags
          nh-os-flags
          outputs
          ;
        hostname = "ENIAC";
        username = "will";
      };

      nh-clean-all-flags = "--keep-since 24h --optimise";
      nh-os-flags = "--bypass-root-check --max-jobs=1";

    in
    {

      nixosConfigurations.${specialArgs.hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs // {
          desktop-and-shit = "kde-plasma";
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

        apps =
          builtins.mapAttrs
            (k: v: {
              program = "${pkgs.writeShellScriptBin k ''
                shopt -s nullglob
                set -euxo pipefail

                ${v}
              ''}/bin/${k}";
              type = "app";
            })
            {
              default = ''
                nix flake update || :
                nix fmt
                nh ${if pkgs.stdenv.isLinux then "os" else "darwin"} switch . ${nh-os-flags}
                nh clean all ${nh-clean-all-flags}
              '';
            };

        checks.style = treefmt.config.build.check self;

        formatter = treefmt.config.build.wrapper;

        packages.darwinConfigurations.${specialArgs.hostname} = nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = specialArgs // {
            desktop-and-shit = "darwin";
          };
          modules = [
            ./configuration.nix
            ./home-manager.nix
            inputs.home-manager.darwinModules.home-manager
            inputs.nixvim.nixDarwinModules.nixvim
          ];
        };

      }
    );
}

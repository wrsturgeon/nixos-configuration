{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils?shallow=1";
    google-fonts = {
      flake = false;
      url = "github:google/fonts/main?shallow=1";
    };
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };
    hyprland = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:hyprwm/hyprland";
    };
    hyprland-plugins = {
      inputs = {
        hyprland.follows = "hyprland";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:hyprwm/hyprland-plugins";
    };
    iosevka = {
      flake = false;
      url = "github:be5invis/iosevka/main?shallow=1";
    };
    nixos-hardware.url = "github:nixos/nixos-hardware/master?shallow=1";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable?shallow=1";
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
      home-manager,
      nixpkgs,
      self,
      treefmt-nix,
      ...
    }:
    let
      inherit (self) outputs;
      inherit (nixpkgs) lib;

      hostname = "ENIAC";
      username = "will";

      compositor = "hyprland";
      desktop-environment = null; # "kde-plasma";

      keyboard = {
        layout = "us";
        options = "caps:swapescape";
        variant = ""; # "colemak_dh";
      };

      unfree-regex = [
        "canon-cups-ufr2"
        "discord"
        "nvidia-.*"
        "spotify.*"
      ];

      specialArgs = {
        inherit
          compositor
          desktop-environment
          hostname
          inputs
          keyboard
          nh-clean-all-flags
          nh-os-flags
          outputs
          unfree-regex
          username
          ;
        home = "/home/${username}";
        stateVersion = "25.05";

        build-users-group = "nixbld";
      };

      nh-clean-all-flags = "--keep-since 24h --optimise";
      nh-os-flags = "--bypass-root-check";

    in
    {

      nixosConfigurations.${specialArgs.hostname} = lib.nixosSystem {
        inherit specialArgs;
        modules = [
          ./hardware-configuration.nix # from the automated hardware scan: don't edit!
          ./nixos-hardware.nix
          ./configuration.nix
          inputs.nixvim.nixosModules.nixvim
          home-manager.nixosModules.home-manager
          ./home-module.nix
        ]
        ++ (if compositor == "hyprland" then [ inputs.hyprland.nixosModules.default ] else [ ]);
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
                nh os switch . -H ${lib.strings.escapeShellArg specialArgs.hostname} ${nh-os-flags}
                nh clean all ${nh-clean-all-flags}
              '';
            };

        checks.style = treefmt.config.build.check self;

        formatter = treefmt.config.build.wrapper;

      }
    );
}

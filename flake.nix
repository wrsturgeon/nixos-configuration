{
  inputs = {
    agenix = {
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:ryantm/agenix";
    };
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };
    hyprland = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:hyprwm/hyprland";
    };
    # linux-src = {
    #   flake = false;
    #   url = "github:torvalds/linux";
    # };
    llama-cpp-src = {
      flake = false;
      url = "github:prismml-eng/llama.cpp";
    };
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixvim = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/nixvim/main";
    };
    ollama-src = {
      flake = false;
      url = "github:ollama/ollama/v0.20.0";
    };
    quickshell = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix/main";
    };
    zen-browser = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:0xc000022070/zen-browser-flake/main";
    };
  };
  outputs =
    inputs@{
      agenix,
      flake-utils,
      home-manager,
      hyprland,
      nixpkgs,
      nixvim,
      self,
      treefmt-nix,
      ...
    }:
    let
      inherit (self) outputs;
      inherit (nixpkgs) lib;

      hostname = "ENIAC";
      username = "will";

      keyboard = {
        layout = "us";
        options = "caps:swapescape";
        variant = ""; # "colemak_dh";
      };

      unfree-regex = [
        "canon-cups-ufr2"
        "cud.*"
        "discord"
        "libcu.*"
        "libnpp"
        "libnv.*"
        "nvidia-.*"
      ];

      specialArgs = {
        inherit
          hostname
          inputs
          keyboard
          nh-clean-all-flags
          nh-os-flags
          nrs
          outputs
          unfree-regex
          username
          ;
        home = "/home/${username}";
        llama-cpp-host = "127.0.0.1";
        llama-cpp-port = 8080;
        ollama-host = "127.0.0.1";
        ollama-port = 11434;
        stateVersion = "25.05";
      };

      nh-clean-all-flags = "--keep-since 24h --optimise";
      nh-os-flags = "-L --bypass-root-check";

      home-module = {
        home-manager = {
          extraSpecialArgs = specialArgs; # what the FUCK: https://www.reddit.com/r/NixOS/comments/1bqzg78
          useGlobalPkgs = true;
          useUserPackages = true;
          # what the FUCK: https://discourse.nixos.org/t/how-to-explicity-pass-arguments-config-and-pkgs-to-home-managers-nixos-module/16607
          users.${username}.imports = [ ./home.nix ];
        };
      };

      nrs = "nh os switch /etc/nixos -H ${lib.strings.escapeShellArg hostname} ${nh-os-flags}";

    in
    {

      nixosConfigurations.${hostname} = lib.nixosSystem {
        inherit specialArgs;
        modules = [
          ./hardware-configuration.nix # from the automated hardware scan: don't edit!
          ./nixos-hardware.nix
          ./configuration.nix
          agenix.nixosModules.default
          hyprland.nixosModules.default
          nixvim.nixosModules.nixvim
          home-manager.nixosModules.home-manager
          home-module
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

        apps = builtins.mapAttrs (k: v: {
          program = "${pkgs.writeShellScriptBin k ''
            shopt -s nullglob
            set -euxo pipefail

            ${v}
          ''}/bin/${k}";
          type = "app";
        }) { default = nrs; };

        checks.style = treefmt.config.build.check self;

        formatter = treefmt.config.build.wrapper;

      }
    );
}

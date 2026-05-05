{
  inputs = {
    agenix = {
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:ryantm/agenix";
    };
    caelestia-shell = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:caelestia-dots/shell";
    };
    desktop-background = {
      flake = false;
      url =
        # "https://wp.presidio.gov/wp-content/uploads/2023/07/tunneltops2410b-1976.jpg";
        # "https://images.pexels.com/photos/30886148/pexels-photo-30886148.jpeg";
        # "https://elephant.art/wp-content/uploads/2019/04/10-2400x1131.jpg";
        "https://images.pexels.com/photos/14993089/pexels-photo-14993089.jpeg";
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
    livekit = {
      flake = false;
      url = "github:livekit/rust-sdks/libwebrtc/v0.3.26";
    };
    llama-cpp-src = {
      flake = false;
      url = "github:prismml-eng/llama.cpp";
    };
    llm-agents = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/llm-agents.nix";
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
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix/main";
    };
    zed-one = {
      flake = false;
      url = "https://raw.githubusercontent.com/zed-industries/zed/refs/heads/main/assets/themes/one/one.json";
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
      github-username = "wrsturgeon";
      username = "will";

      keyboard = {
        layout = "us";
        options = "caps:swapescape";
        variant = ""; # "colemak_dh";
      };

      location =
        let
          latitude = "37.8";
          longitude = "-122.4";
        in
        {
          inherit latitude longitude;
          weatherLocation = "${latitude},${longitude}";
        };

      unfree-regex = [
        "canon-cups-ufr2"
        "cud.*"
        "discord"
        "libcu.*"
        "libnpp"
        "libnv.*"
        "nvidia-.*"
        "spotify"
      ];

      specialArgs = {
        inherit
          github-username
          hostname
          inputs
          keyboard
          location
          nh-clean-all-flags
          nh-os-flags
          nrs
          outputs
          unfree-regex
          username
          ;
        default-font = "Inter Variable"; # "IBM Plex Sans";
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

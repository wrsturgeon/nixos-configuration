# TODO: read & integrate <https://xeiaso.net/blog/paranoid-nixos-2021-07-18/>
{
  inputs = {
    agenix = {
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:ryantm/agenix";
    };
    aspekta = {
      flake = false;
      url = "github:ivodolenc/aspekta";
    };
    bluu-next = {
      flake = false;
      url = "github:velvetyne/bluunext";
    };
    caelestia-shell = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:caelestia-dots/shell";
    };
    contributron = {
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
        treefmt-nix.follows = "treefmt-nix";
      };
      url = "github:wrsturgeon/contributron";
    };
    desktop-background = {
      flake = false;
      # url = "https://images.pexels.com/photos/14993089/pexels-photo-14993089.jpeg";
      # url = "https://i.redd.it/1pkov1b2tyve1.jpeg";
      url = "https://dn721309.ca.archive.org/0/items/theoriginalfilesofsomewindowswallpapers/bliss%20600dpi.jpg";
    };
    emacs-overlay = {
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs";
      };
      url = "github:nix-community/emacs-overlay";
    };
    flake-utils.url = "github:numtide/flake-utils";
    google-fonts = {
      flake = false;
      url = "github:google/fonts";
    };
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };
    hyprland = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:hyprwm/hyprland";
    };
    llm-agents = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/llm-agents.nix";
    };
    # microvm = {
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   url = "github:microvm-nix/microvm.nix";
    # };
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixvim = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/nixvim/main";
    };
    onedark = {
      flake = false;
      url = "https://raw.githubusercontent.com/navarasu/onedark.nvim/refs/heads/master/lua/onedark/palette.lua";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix/main";
    };
    uncut-sans = {
      flake = false;
      url = "github:kaspernordkvist/uncut_sans";
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
      # microvm,
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
          # San Francisco:
          # latitude = "37.8";
          # longitude = "-122.4";
          # 250 Vesey Street, NYC:
          latitude = "40.7";
          longitude = "-74.0";
        in
        {
          inherit latitude longitude;
          weatherLocation = "${latitude},${longitude}";
        };

      unfree-regex = [
        "canon-cups-ufr2"
        "codex-desktop"
        "cud.*"
        "libcu.*"
        "libnpp"
        "libnv.*"
        "nvidia-.*"
        "spotify"
      ];

      hyprlandFor = system: hyprland.packages.${system}.hyprland.override { enableXWayland = false; };

      hyprlandPortalFor =
        system:
        hyprland.packages.${system}.xdg-desktop-portal-hyprland.override { hyprland = hyprlandFor system; };

      hyprlandOverlay = final: _prev: {
        hyprland = hyprlandFor final.stdenv.hostPlatform.system;
        xdg-desktop-portal-hyprland = hyprlandPortalFor final.stdenv.hostPlatform.system;
      };

      hyprlandModule =
        { config, pkgs, ... }:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          hyprlandPackage = hyprlandFor system;
          hyprlandPortalPackage = hyprlandPortalFor system;
        in
        {
          assertions = [
            {
              assertion = config.programs.hyprland.package.drvPath == hyprlandPackage.drvPath;
              message = "programs.hyprland.package must be the canonical no-XWayland Hyprland package.";
            }
            {
              assertion = config.programs.hyprland.portalPackage.drvPath == hyprlandPortalPackage.drvPath;
              message = "programs.hyprland.portalPackage must be paired with the canonical Hyprland package.";
            }
            {
              assertion = pkgs.hyprland.drvPath == hyprlandPackage.drvPath;
              message = "pkgs.hyprland must be the canonical no-XWayland Hyprland package.";
            }
            {
              assertion = !config.programs.hyprland.xwayland.enable;
              message = "Hyprland is intentionally hard-coded without XWayland.";
            }
          ];

          nixpkgs.overlays = [ hyprlandOverlay ];

          programs.hyprland = {
            package = hyprlandPackage;
            portalPackage = hyprlandPortalPackage;
            xwayland.enable = false;
          };
        };

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
        # Spline Sans with its ss02 double-decker g baked in; see spline-sans-ss02 in configuration.nix.
        default-font = "Spline Sans SS02"; # "Mallory Trial MP Narrow"; # "Taurus Grotesk Trial"; # "Bricolage Grotesque 92.5"; # "GT America 95"; # "Instrument Sans 90"; # "Inter"; # "IBM Plex Sans";
        default-monospace-font = "Iosevka Custom";
        default-serif-font = "Test Martina Plantijn";
        home = "/home/${username}";
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
          users = {
            ${username}.imports = [ ./home.nix ];
            root = {
              imports = [ ./pi/home-manager.nix ];
              home = {
                username = "root";
                homeDirectory = "/root";
                inherit (specialArgs) stateVersion;
              };
            };
          };
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
          home-manager.nixosModules.home-manager
          home-module
          hyprland.nixosModules.default
          hyprlandModule
          # microvm.nixosModules.microvm
          nixvim.nixosModules.nixvim
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

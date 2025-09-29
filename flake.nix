{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils?shallow=1";
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager?shallow=1";
    };
    hyprland = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:hyprwm/hyprland?shallow=1";
    };
    kicad-src = {
      flake = false;
      url = "git+https://gitlab.com/kicad/code/kicad.git?ref=9.0&shallow=1";
    };
    nixos-hardware.url = "github:nixos/nixos-hardware?shallow=1";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable?shallow=1";
    nixvim = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/nixvim?shallow=1";
    };
    rust-overlay = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:oxalica/rust-overlay?shallow=1";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix?shallow=1";
    };
    zen-browser = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:0xc000022070/zen-browser-flake?shallow=1";
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
      specialArgs = {
        inherit inputs outputs;
        desktop-and-shit = "kde-plasma";
        hostname = "ENIAC";
        username = "will";
      };
      full-os-config = nixpkgs.lib.nixosSystem {
        inherit specialArgs;
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix # from the automated hardware scan: don't edit!
          ./home-manager.nix
          ./nixos-hardware.nix
          inputs.home-manager.nixosModules.home-manager
          inputs.nixvim.nixosModules.nixvim
        ];
      };
    in
    {
      nixosConfigurations = {
        nixos = full-os-config;
        ${specialArgs.hostname} = full-os-config;
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        treefmt = treefmt-nix.lib.evalModule pkgs ./.treefmt.nix;
      in
      {
        checks.style = treefmt.config.build.check self;
        formatter = treefmt.config.build.wrapper;
        # packages.nixos = full-os-config;
      }
    );
}

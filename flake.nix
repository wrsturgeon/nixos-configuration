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
    assert-dendritic.url = "path:./assert-dendritic";
    bluu-next = {
      flake = false;
      url = "github:velvetyne/bluunext";
    };
    caelestia-shell = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:caelestia-dots/shell";
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
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
      url = "github:hercules-ci/flake-parts";
    };
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
    import-tree.url = "github:denful/import-tree";
    llm-agents = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/llm-agents.nix";
    };
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
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
    { flake-parts, import-tree, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (import-tree ./modules);
}

{ config, ... }:

let
  inherit (config.local) unfree-regex username;
in
{
  config.local.nixos.modules.host = { lib, ... }: {
    nix = {
      channel.enable = false;
      daemonCPUSchedPolicy = "idle";
      daemonIOSchedClass = "idle";
      enable = true;
      settings = {
        experimental-features = [
          "cgroups"
          "flakes"
          "nix-command"
        ];
        extra-substituters = [
          "https://cache.nixos-cuda.org"
          "https://cache.numtide.com"
          "https://nix-community.cachix.org"
        ];
        extra-trusted-public-keys = [
          "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
        http-connections = 0; # unlimited
        log-lines = 48;
        min-free = "32G";
        preallocate-contents = true;
        require-sigs = true;
        sandbox = true;
        show-trace = true;
        stalled-download-timeout = 60; # seconds
        sync-before-registering = true;
        trusted-users = [ username ];
        use-xdg-base-directories = true;
        use-cgroups = true;
        warn-large-path-threshold = "1G";

      };
    };

    nixpkgs = {
      config = {
        allowUnfreePredicate =
          pkg: builtins.any (regex: (builtins.match regex (lib.getName pkg)) != null) unfree-regex;
        cudaSupport = true;
        nvidia.acceptLicense = true;
      };
    };

  };
}

{ pkgs, username, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users."${username}" = import ./home-manager { inherit pkgs username; };
  };
}

{
  desktop-and-shit,
  pkgs,
  username,
  ...
}:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users."${username}" = import ./home-manager { inherit desktop-and-shit pkgs username; };
  };
}

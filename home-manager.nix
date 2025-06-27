{
  pkgs,
  inputs,
  outputs,
  username,
  ...
}@args:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # users = builtins.mapAttrs (
    #   k: v:
    #   assert v == "directory";
    #   import "${./users}/${k}"
    # ) (builtins.readDir ./users);
    users."${username}" = import ./home-manager args;
  };
}

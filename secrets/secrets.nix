let
  publicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ+jHVxvcLcoewif91FnKMiAWNZJA3Q+aCPAngsKsgHr root@ENIAC"
  ];
  secrets = {
    "passwd.age" = { };
    "wifi-apt.age" = { };
  };
in
builtins.mapAttrs (_k: v: { inherit publicKeys; } // v) secrets

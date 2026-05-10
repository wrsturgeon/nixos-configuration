let
  publicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ+jHVxvcLcoewif91FnKMiAWNZJA3Q+aCPAngsKsgHr root@ENIAC"
  ];
  secrets = {
    "absans.tar.gz.age" = { };
    "blanco.tar.gz.age" = { };
    "foss-serif.tar.gz.age" = { };
    "gt-america-trial-vf.ttf.age" = { };
    "gh-pat.age" = { };
    "passwd.age" = { };
    "martina-plantijn.tar.gz.age" = { };
    "signifier.tar.gz.age" = { };
    "taurus-grotesk.tar.gz.age" = { };
    "wifi-apt.age" = { };
    "wifi-mox.age" = { };
    "wifi-nb.age" = { };
    "wifi-la.age" = { };
  };
in
builtins.mapAttrs (_k: v: { inherit publicKeys; } // v) secrets

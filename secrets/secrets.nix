let
  publicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ+jHVxvcLcoewif91FnKMiAWNZJA3Q+aCPAngsKsgHr root@ENIAC"
  ];
  secrets = {
    "absans.tar.gz.age" = { };
    "blanco.tar.gz.age" = { };
    "foss-serif.tar.gz.age" = { };
    "griffith-gothic-normal-trial-otf.zip.age" = { };
    "gt-america-trial-vf.ttf.age" = { };
    "gh-pat.age" = { };
    "passwd.age" = { };
    "mallory-trial-compact-otf.zip.age" = { };
    "mallory-trial-narrow-otf.zip.age" = { };
    "mallory-trial-normal-otf.zip.age" = { };
    "martina-plantijn.tar.gz.age" = { };
    "seaford-trial-otf.zip.age" = { };
    "signifier.tar.gz.age" = { };
    "taurus-grotesk.tar.gz.age" = { };
    "wifi-apt.age" = { };
    "wifi-mox.age" = { };
    "wifi-nb.age" = { };
    "wifi-la.age" = { };
  };
in
builtins.mapAttrs (_k: v: { inherit publicKeys; } // v) secrets

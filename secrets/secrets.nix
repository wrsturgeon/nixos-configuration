let
  publicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfn5n9oinncL3gOEIjTKqRZyhOuxoqxwDoo40tOprmG willstrgn@gmail.com" # will
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtj9HPUAKJGQDKYITqcxwUePEkxxfEEVND90yS5GdgD willstrgn@gmail.com" # root
  ];
  secrets = {
    "passwd.age" = { };
    "wifi-ssid.age" = { };
    "wifi-psk.age" = { };
  };
in
builtins.mapAttrs (_k: v: { inherit publicKeys; } // v) secrets

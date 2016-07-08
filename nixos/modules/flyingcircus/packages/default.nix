{ ... }:

{

  imports = [
    ./percona
  ];

  nixpkgs.config.packageOverrides = pkgs: rec {

    boost159 = pkgs.callPackage ./boost-1.59.nix { };

    cron = pkgs.callPackage ./cron.nix { };

    easyrsa3 = pkgs.callPackage ./easyrsa { };

    fcmaintenance = pkgs.callPackage ./fcmaintenance { };
    fcmanage = pkgs.callPackage ./fcmanage { };
    fcsensuplugins = pkgs.callPackage ./fcsensuplugins { };
    fcutil = pkgs.callPackage ./fcutil { };

    nagiosplugin = pkgs.callPackage ./nagiosplugin.nix { };

    powerdns = pkgs.callPackage ./powerdns.nix { };
    pypkgs = pkgs.callPackage ./pypkgs.nix { };

    qemu = pkgs.callPackage ./qemu-2.5.nix {
      inherit (pkgs.darwin.apple_sdk.frameworks) CoreServices Cocoa;
      x86Only = true;
    };

    sensu = pkgs.callPackage ./sensu { };
    uchiwa = pkgs.callPackage ./uchiwa { };

    mc = pkgs.callPackage ./mc.nix { };

    osm2pgsql = pkgs.callPackage ./osm2pgsql.nix { };

  };
}

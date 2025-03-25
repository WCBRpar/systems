{ config, lib, pkgs, sources, ... }:

let

  # sites = import ./sites { inherit lib; };

  sources = import ../../npins;
  wp4nix = pkgs.callPackage sources.wp4nix {};

  imports = [ ./sites ];

in

{

  environment.systemPackages = with pkgs; [ php ];
  environment.variables.WP_VERSION = "6.4";
    

}



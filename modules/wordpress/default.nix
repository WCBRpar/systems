{ config, lib, pkgs, sources, ... }:

let

wp4nix = pkgs.callPackage sources.wp4nix { };
  # sites = import ./sites.nix { inherit lib; };

in

{
  # security.acme = lib.mkIf ( config.networking.hostName == "pegasus" )  {
  #   certs."${sites.site.domain}"= {
  #     extraDomainNames = [ "*.${sites.site.domain}" "*.${sites.site.domain}" ];
  #  };
  # };
}



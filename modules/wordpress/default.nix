{ config, lib, pkgs, sites, sources, ... }: 

let

  wp4nix = pkgs.callPackage sources.wp4nix { };

  sites = import ./sites.nix { inherit lib; };

in

with sites;

rec {

  security.acme = lib.mkIf ( config.networking.hostName == "pegasus" )  {
    certs."${sites.domain}"= {
      extraDomainNames = [ "*.${sites.domain}" "*.${sites.domain}" ];
    };
  };

}


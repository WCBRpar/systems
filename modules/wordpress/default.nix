{ config, lib, pkgs, sources, ... }:

let

  wp4nix = pkgs.callPackage sources.wp4nix { };
  # imports = [ ./sites.nix ];

in

{

  services.wordpress = {
    webserver = "nginx";

    sites = {
      "oposicaopararenovarandes" = {};

    };
  };


  #
  # Estava tentando uma nova abordagem, mas parece-me que o
  # módulo nixos/services/web-apps/wordpres.nix dá conta 
  #

  # services.wp-sites = {
  #   RED = {
  #     "redcom.digital" = {
  #       organization = "wcbrpar.com";
  #       siteType = { 
  # 	  "wordpress" = {
  # 	    plugins = '' 
  # 	      co-authores-plus
  # 	      google-site-kit
  #  	    '';
  #  	    themes = ''
  # 	      astra
  # 	    '';
  #         };
  #       };
  #     };
  #   };
  # };
}



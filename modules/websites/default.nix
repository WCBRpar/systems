{ config, lib, pkgs, sources, ... }:


let 

  sources = import ../../npins;
  wp4nix = pkgs.callPackage sources.wp4nix {};

in

{
  imports = [ ./sites ./sites/fix-adf.nix ./sites/fix-ham.nix ./sites/fix-evm.nix ];

  environment.systemPackages = with pkgs; [ php ];
  environment.variables.WP_VERSION = "6.4";
  
  mkSite = {

    "RED" = {
      enable = true;
      siteFQDN = "redcom.digital";
      siteType = "wordpress";
      themes = {
        inherit (pkgs.wordpressPackages.themes) twentytwentythree;
        inherit (wp4nix.themes) astra;
      };
      plugins = {
        # inherit (pkgs.wordpressPackages.plugins) akismet;
        inherit (wp4nix.plugins) google-site-kit;
      };
      extraConfig = ''
        define('WP_DEBUG', true);
      '';
    };

    "CH4" = {
      enable = true;
      siteFQDN = "oposicaopararenovarandes.com.br";
      siteType = "wordpress";
      themes = {
        inherit (pkgs.wordpressPackages.themes) twentytwentythree;
        inherit (wp4nix.themes) astra;
      };
      plugins = {
        # inherit (pkgs.wordpressPackages.plugins) akismet;
        inherit (wp4nix.plugins) woocommerce;
      };
    };

    "STR" = {
      enable = true;
      siteFQDN = "setra.com.br";
      siteType = "estatico";
      siteRoot = "/var/lib/www/setra.com.br";
    };
    
  };

}



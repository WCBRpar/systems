{ config, lib, pkgs, sources, ... }:


let 

  sources = import ../../npins;
  wp4nix = pkgs.callPackage sources.wp4nix {};

in

{
  imports = [ ./sites ];

  environment.systemPackages = with pkgs; [ php ];
  environment.variables.WP_VERSION = "6.4";
  
  wp-sites = {
    "RED" = {
      domain = "redcom.digital";
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
      domain = "oposicaopararenocarandes.com.br";
      themes = {
        inherit (pkgs.wordpressPackages.themes) twentytwentythree;
        inherit (wp4nix.themes) astra;
      };
      plugins = {
        # inherit (pkgs.wordpressPackages.plugins) akismet;
        inherit (wp4nix.plugins) woocommerce;
      };
    };
  };

}



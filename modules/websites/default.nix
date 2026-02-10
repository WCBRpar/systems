{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  wp4nix = pkgs.callPackage inputs.wp4nix {};

in

{

  imports = [ ./sites ./sites/fix-adf.nix ];

  environment.systemPackages = with pkgs; [php];
  environment.variables.WP_VERSION = "6.7";

  mkSite = {
    "RED" = {
      enable = true;
      siteFQDN = "redcom.digital";
      siteType = "wordpress";
      wordpress = {
        package = pkgs.wordpress_6_7;
        themes = {
          inherit (pkgs.wordpressPackages.themes) twentytwentythree;
          inherit (wp4nix.themes) astra;
        };
        plugins = {
          inherit (wp4nix.plugins)
            add-widget-after-content
            antispam-bee
            async-javascript
            code-syntax-block
            custom-post-type-ui
            disable-xml-rpc
            google-site-kit
            gutenberg
            official-facebook-pixel
            opengraph
            static-mail-sender-configurator
            wp-user-avatars;
        };
        settings = {
          WP_DEBUG = true;
          WP_DEBUG_LOG = true;
        };
      };
    };

    "CMS" = {
      enable = true;
      siteFQDN = "cutms.org.br";
      siteType = "wordpress";
      # Usando porta diferente (sobrescrevendo o padrão)
      proxy.backendUrl = "https://pegasus.wcbrpar.com:8001";
      wordpress = {
        plugins = {
          inherit (pkgs.wordpressPackages.plugins)
            co-authors-plus
            simple-mastodon-verification
            surge
            wordpress-seo
            webp-converter-for-media;
          inherit (wp4nix.plugins)
            antispam-bee
            async-javascript
            google-site-kit
            official-facebook-pixel
            wpforms-lite;
        };
        themes = {
          inherit (pkgs.wordpressPackages.themes) twentytwentythree twentytwentyfive;
          inherit (wp4nix.themes) astra;
        };
        settings = {
          FORCE_SSL_ADMIN = false;
        };
      };
    };

    "STR" = {
      enable = true;
      siteFQDN = "setra.com.br";
      siteType = "estatico";
      proxy.enable = false;
    };
  };
}


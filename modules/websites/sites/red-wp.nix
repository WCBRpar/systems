{ config, pkgs, lib, inputs, options, ... }:

let

  app = "red";
  name = "redcom";
  domain = "${name}.digital";
  organization = "wcbrpar.com";

  # imports = [ ./aux-functions.nix ];

  sources = import ../../../npins;
  wp4nix = pkgs.callPackage sources.wp4nix {};

in

lib.mkIf ( config.networking.hostName == "pegasus" ) {

  security.acme = {
    certs."${organization}" = {
      extraDomainNames = [ "*.${domain}" ];
      # webroot = "/var/lib/acme/${organization}";
      dnsProvider = "cloudflare";
      group = "nginx";
    };
  };

  services = {
    phpfpm.pools."wordpress-${domain}".phpOptions = ''
      upload_max_filesize = 128M
      post_max_size = 128M
      memory_limit = 256M
    '';
    wordpress = {
      webserver = "nginx";
      sites = {
        "${domain}" = {
          package = pkgs.wordpress_6_7;
          database = {
            createLocally = true;
            name = "wpdb_${name}";
          };
          plugins = {
            inherit (pkgs.wordpressPackages.plugins)
              add-widget-after-content
              antispam-bee
              async-javascript
              breeze
              code-syntax-block
              co-authors-plus
              disable-xml-rpc
              jetpack
              jetpack-lite
              # mailpoet
              opengraph
              simple-login-captcha
              simple-mastodon-verification
              # svg-support - Pack
              static-mail-sender-configurator
              webp-converter-for-media
              # wordpress-importer
              wp-gdpr-compliance
              wp-mail-smtp
              wp-statistics
              wp-user-avatars;
            inherit (wp4nix.plugins)
              google-site-kit;
          };
          themes = {
            inherit (wp4nix.themes) astra;
	    inherit (pkgs.wordpressPackages.themes) twentytwentythree;
          };
          languages = [ wp4nix.languages.pt_BR ];
          settings = {
            WP_DEFAULT_THEME = "twentytwentythree";
            WP_MAIL_FROM = "gcp-devops@wcbrpar.com";
            WP_SITEURL = "https://${domain}";
            WP_HOME = "https://${domain}";
            WPLANG = "pt_BR";
            AUTOMATIC_UPDATER_DISABLED = true;
            # FORCE_SSL_ADMIN = false;
          };
          poolConfig = {
            "pm" = "dynamic";
            "pm.max_children" = 64;
            "pm.max_requests" = 500;
            "pm.max_spare_servers" = 4;
            "pm.min_spare_servers" = 2;
            "pm.start_servers" = 2;
          };
          virtualHost = {
            robotsEntries = ''
              User-agent: *
              Disallow: /feed/
              Disallow: /trackback/
              Disallow: /wp-admin/
              Disallow: /wp-content/
              Disallow: /wp-includes/
              Disallow: /xmlrpc.php
              Disallow: /wp-
            '';
            addSSL = false;

          };
        };
      };
    };
    nginx.virtualHosts = {

      "${domain}" = {
        useACMEHost = "${organization}";
        addSSL = true;
        locations."/.well-known/acme-challenge" = {
          root = "/var/lib/acme/${organization}";
        };
        locations."/" = {
          root = "/var/lib/www/${domain}";
          extraConfig = ''
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:${config.services.phpfpm.pools."wordpress-${domain}".socket};
            include ${pkgs.nginx}/conf/fastcgi_params;
            include ${pkgs.nginx}/conf/fastcgi.conf;
          '';
        };
      };

      "${domain}80" = {
        serverName = "${domain}";
        locations."/.well-known/acme-challenge" = {
          root = "/var/lib/acme/${domain}";
          extraConfig = ''
            auth_basic off;
          '';
        };
        locations."/" = { return = "301 https://$host$request_uri"; };
      };

      "${app}.${domain}" = {
        globalRedirect = "${domain}";
      };
    };
  };

}






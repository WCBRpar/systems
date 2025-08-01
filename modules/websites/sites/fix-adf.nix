{ config, pkgs, lib, inputs, options, ... }:

let
  sources = import ../../../npins;
  wp4nix = pkgs.callPackages sources.wp4nix {};

  app = "red";
  name = "adufms";
  domain = "${name}.org.br";
in
{
  services = {
    traefik.dynamicConfigOptions = lib.mkIf (config.networking.hostName == "galactica") {
      http = {
        routers = {
          WP-ADF = {
            rule = "Host(`adufms.org.br`)";
            service = "adufms-site";
            entrypoints = ["websecure"];
            tls = {
              certResolver = "cloudflare";
            };
          };
        };

        services = {
          adufms-site = {
            loadBalancer = {
              servers = [{ url = "https://pegasus.wcbrpar.com:8001"; }];
              # Importante para lidar com redirecionamentos:
              passHostHeader = true;
            };
          };
        };
      };
    };

  # security.acme = {
  #   certs."${domain}" = {
  #     extraDomainNames = [ "*.${domain}" ];
  #     webroot = "/var/lib/acme/${domain}";
  #     group = "nginx";
  #   };
  # };

  
    phpfpm.pools = lib.mkIf (config.networking.hostName == "pegasus") {
      "wordpress-${domain}".phpOptions = ''
        upload_max_filesize = 128M
        post_max_size = 128M
        memory_limit = 256M
      '';
    };

    wordpress = lib.mkIf (config.networking.hostName == "pegasus") {
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
	      # simple-popup-block
	      ;
            inherit (wp4nix.plugins)
              add-widget-after-content
              antispam-bee
              async-javascript
              code-syntax-block
              custom-post-type-ui
              # co-authors-plus   Temporariamente indisponivel
              disable-xml-rpc
              google-site-kit
              gutenberg
	      notification
	      official-facebook-pixel
              opengraph
	      rss-importer
	      # simple-popup-block
              static-mail-sender-configurator
              # webp-converter-for-media
	      wp-popups-lite
              wp-user-avatars
	      wp-rss-aggregator
	      ;
          };
          themes = {
            inherit (pkgs.wordpressPackages.themes)
              twentytwentythree;
            inherit (wp4nix.themes) 
              astra;
          };
          # languages = [ pkgs.wordpressPackages.languages.pt_BR ];
          settings = {
            WP_DEFAULT_THEME = "twentytwentythree";
            WP_MAIL_FROM = "gcp-devops@wcbrpar.com";
            WP_SITEURL = "https://adufms.org.br";
            WP_HOME = "https://adufms.org.br";
            WPLANG = "pt_BR";
            AUTOMATIC_UPDATER_DISABLED = true;
            FORCE_SSL_ADMIN = true;
            WP_DEBUG = true;
            WP_DEBUG_LOG = true;
            WP_DEBUG_DISPLAY = false;
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
            # addSSL = true;
          };
        };
      };
    };

    nginx.virtualHosts = lib.mkIf (config.networking.hostName == "pegasus") {
      "${domain}" = {
        enableACME = true;
        # useACMEHost = "${domain}";
        addSSL = true;
        locations."/.well-known/acme-challenge" = {
          root = "/var/lib/acme/${domain}";
        };
        locations."~ \.php$" = {
          root = "/var/www/${domain}";
          extraConfig = ''
            fastcgi_index index.php;
            fastcgi_split_path_info ^(.+\.php)(/.*)$;
            try_files $uri $uri/ index.php /index.php$is_args$args;
            include ${pkgs.nginx}/conf/fastcgi_params;
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            fastcgi_param APP_ENV dev;
          '';
        };
        locations."~* (.*\.pdf)" = {
          extraConfig = ''
	    types { application/pdf .pdf; }
	    default_type application/pdf;
	    more_set_headers Content-Disposition "inline" always;
    	    more_set_headers X-Content-Type-Options "nosniff";
    	    expires 30d;
    	    more_set_headers Cache-Control "public, no-transform" always;
	    proxy_hide_header Content-Disposition;
    	    proxy_hide_header X-Content-Type-Options;
	    proxy_ignore_headers Set-Cookie;
	    proxy_set_header Connection "";
          '';
        };

        locations."/" = {
          root = "/var/www/${domain}";
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
        # locations."/" = { return = "301 https://$host$request_uri"; };
      };

      "${app}.${domain}" = {
        globalRedirect = "${domain}";
      };
    };
  };
}

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types;
  sources = import ../../../npins;
  wp4nix = pkgs.callPackage sources.wp4nix {};

  extractDomainRoot = domain:
    let
      parts = lib.splitString "." domain;
      root = if lib.length parts > 2 
             then lib.head parts
             else lib.elemAt parts (lib.length parts - 2);
    in
    lib.toLower root;

in {
  options.wp-sites = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        domain = mkOption {
          type = types.str;
          example = "nomedosite.com.br";
          description = "Domínio completo do site";
        };
        themes = mkOption {
          type = types.attrsOf types.package;
          default = {};
          description = "Temas WordPress";
        };
        plugins = mkOption {
          type = types.attrsOf types.package;
          default = {};
          description = "Plugins WordPress";
        };
        languages = mkOption {
          type = types.listOf types.package;
          default = [ wp4nix.languages.pt_BR ];
          description = "Pacotes de idiomas WordPress";
        };
        extraConfig = mkOption {
          type = types.lines;
          default = "";
          description = "Configurações extras do wp-config.php";
        };
        settings = mkOption {
          type = types.attrs;
          default = {};
          description = "Configurações adicionais";
        };
      };
    });
    default = {};
    description = "Sites WordPress configurados";
  };

  config = lib.mkIf (
    config.networking.hostName == "pegasus" &&
    (builtins.length (lib.attrValues config.wp-sites) > 0)
  ) {
    services.wordpress.webserver = "nginx";
    security.acme.acceptTerms = true;

    services.wordpress.sites = lib.mapAttrs' (name: site: {
      name = site.domain;
      value = {
        package = pkgs.wordpress;

        virtualHost = {
          hostName = site.domain;
          useACMEHost = site.domain;
          forceSSL = true;
          enableACME = true;
          extraConfig = ''
            access_log /var/log/nginx/${site.domain}.access.log;
            error_log /var/log/nginx/${site.domain}.error.log;

            # Security headers (complementares aos globais)
            # add_header X-XSS-Protection "1; mode=block";
            # add_header Permissions-Policy "geolocation=(), midi=(), sync-xhr=(), microphone=(), camera=(), magnetometer=(), gyroscope=(), fullscreen=(self), payment=()";

          '';
          locations = {
            "/" = {
	      index = "index.php index.html index.htm";
              tryFiles = "$uri $uri/ /index.php?$args";
            };
            "~ \.php$" = {
              extraConfig = ''
                include ${pkgs.nginx}/conf/fastcgi_params;
                fastcgi_pass unix:${config.services.phpfpm.pools.wordpress.socket};
                fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                fastcgi_param HTTPS $http_x_forwarded_proto;
                fastcgi_param HTTP_X_FORWARDED_PROTO $http_x_forwarded_proto;
              '';
            };
          };
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
        } // (site.settings.virtualHost or {});

        settings = (site.settings or {}) // {
          poolSettings = ''
            pm = dynamic
            pm.max_children = 64
            pm.max_requests = 500
            pm.max_spare_servers = 4
            pm.min_spare_servers = 2
            pm.start_servers = 2
          '';
        };

        database = {
          name = "wpdb_${extractDomainRoot site.domain}";
          host = "localhost";
          createLocally = true;
        };

        themes = site.themes;
        plugins = site.plugins;
        languages = site.languages;

        extraConfig = ''
          define('WPLANG', 'pt_BR');
          define('WP_HOME', 'https://${site.domain}');
          define('WP_SITEURL', 'https://${site.domain}');
	  @init_set('display_errors', 0);
          
          // Cloudflare compatibility
          if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https') {
            $_SERVER['HTTPS'] = 'on';
          }
          ${site.extraConfig}
        '';
      };
    }) config.wp-sites;
  };
}

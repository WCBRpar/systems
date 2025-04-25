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
  options.mkSites = mkOption {
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
    (builtins.length (lib.attrValues config.mkSites) > 0)
  ) {
    services.wordpress.webserver = "nginx";
    security.acme.acceptTerms = true;

    services.wordpress.sites = lib.mapAttrs' (name: site: {
      name = site.domain;
      value = {
        package = pkgs.wordpress;

        virtualHost = {
          hostName = site.domain;
          forceSSL = false;
          enableACME = true;
          extraConfig = ''
	    # Cloudflare
            # real_ip_header CF-Connecting-IP;

            if ($http_x_forwarded_proto = "https") {
              set $https_redirect "off";
            }
          '';

          locations = {
            "/" = {
              index = "index.php index.html index.htm";
              tryFiles = "$uri $uri/ /index.php?$args";
            };
            "~ \.php$" = {
              extraConfig = ''
	        fastcgi_split_path_info ^(.+\.php)(/.+)$;
                include ${pkgs.nginx}/conf/fastcgi_params;
                include ${pkgs.nginx}/conf/fastcgi.conf;
                fastcgi_pass unix:${config.services.phpfpm.pools."wordpress-${site.domain}".socket};
                
                # Configurações críticas para HTTPS
                fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                fastcgi_param HTTPS $http_x_forwarded_proto;
                fastcgi_param HTTP_X_FORWARDED_PROTO $http_x_forwarded_proto;
              '';
            };
          };
        };

        settings = (site.settings or {}) // {
          WP_SITEURL = "https://${site.domain}";
          WP_HOME = "https://${site.domain}";
          WPLANG = "pt_BR";
          AUTOMATIC_UPDATER_DISABLED = true;
          FORCE_SSL_ADMIN = true;
        };

        poolConfig = {
          "pm" = "dynamic";
          "pm.max_children" = 32;
          "pm.start_servers" = 4;
          "pm.min_spare_servers" = 4;
          "pm.max_spare_servers" = 8;
          "pm.max_requests" = 500;
          "php_admin_value[error_log]" = "stderr";
          "php_admin_flag[log_errors]" = true;
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
          $_SERVER['HTTPS'] = 'on';
          $_SERVER['SERVER_PORT'] = 443;
          ${site.extraConfig}
        '';
      };
    }) config.wp-sites;
  };
}

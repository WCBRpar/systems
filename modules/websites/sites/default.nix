# modules/websites/sites/default.nix
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption types mkIf filterAttrs mapAttrs' mkDefault attrNames nameValuePair listToAttrs mapAttrsToList;
  sources = import ../../../npins;
  wp4nix = pkgs.callPackage sources.wp4nix {};

  countEnabledSites = sites:
    lib.length (lib.attrNames (lib.filterAttrs (_: site: site.enable) sites));

  enabledWpSites = filterAttrs (_: site: site.enable && site.siteType == "wordpress") config.mkSite;

in {
  options.mkSite = mkOption {
    type = types.attrsOf (types.submodule ({ name, config, ... }: {
      options = {
        enable = mkEnableOption "Habilitar este site específico";
        
        siteType = mkOption {
          type = types.enum [ "wordpress" "estatico" ];
          default = "wordpress";
          description = "Tipo da implementação do site";
        };

        siteFQDN = mkOption {
          type = types.str;
          description = "Domínio completo (FQDN) do site";
        };

        # Opções genéricas de Proxy (Traefik)
        proxy = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Habilitar configuração de proxy reverso (Traefik)";
          };
          host = mkOption {
            type = types.str;
            default = "galactica";
            description = "Hostname onde o Traefik está rodando";
          };
          backendUrl = mkOption {
            type = types.str;
            default = "https://pegasus.wcbrpar.com:7770";
            description = "URL do backend para o Traefik";
          };
        };

        # Opções para WordPress
        wordpress = {
          package = mkOption {
            type = types.package;
            default = pkgs.wordpress;
            description = "Pacote do WordPress a ser utilizado";
          };

          databaseName = mkOption {
            type = types.str;
            default = "wpdb_${lib.toLower name}";
            description = "Nome do banco de dados";
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

          settings = mkOption {
            type = types.attrs;
            default = {};
            description = "Configurações WP_SETTINGS";
          };

          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = "Configurações extras do wp-config.php";
          };

          phpOptions = mkOption {
            type = types.lines;
            default = ''
              upload_max_filesize = 128M
              post_max_size = 128M
              memory_limit = 256M
            '';
            description = "Opções extras do PHP para o pool";
          };

          poolConfig = mkOption {
            type = types.attrs;
            default = {
              "pm" = "dynamic";
              "pm.max_children" = 64;
              "pm.max_requests" = 500;
              "pm.max_spare_servers" = 4;
              "pm.min_spare_servers" = 2;
              "pm.start_servers" = 2;
            };
            description = "Configuração do pool PHP-FPM";
          };
        };

        # Opção para sites estáticos
        siteRoot = mkOption {
          type = types.path;
          default = "/var/lib/www/${config.siteFQDN}";
          description = "Caminho raiz do conteúdo estático";
        };
      };
    }));
    default = {};
    description = "Sites configurados para servir";
  };

  config = mkIf (countEnabledSites config.mkSite > 0) (lib.mkMerge [
    # Configuração Traefik (roda no galactica)
    {
      services.traefik.dynamicConfigOptions = lib.mkIf (config.networking.hostName == "galactica") {
        http = {
          routers = listToAttrs (mapAttrsToList (id: site:
            nameValuePair "WP-${id}" {
              rule = "Host(`${site.siteFQDN}`)";
              service = "wordpress-server";
              entrypoints = ["websecure"];
              tls.certResolver = "cloudflare";
            }
          ) (filterAttrs (_: site: site.enable && site.proxy.enable) config.mkSite));

          services = {
            "wordpress-server" = {
              loadBalancer = {
                servers = [{ url = "https://pegasus.wcbrpar.com:7770"; }];
                passHostHeader = true;
              };
            };
          };
        };
      };
    }

    # Configurações WordPress (roda no pegasus)
    (lib.mkIf (config.networking.hostName == "pegasus") {
      services.wordpress.webserver = "nginx";
      services.wordpress.sites = listToAttrs (mapAttrsToList (id: site:
        nameValuePair site.siteFQDN {
          package = site.wordpress.package;
          database = {
            createLocally = true;
            name = site.wordpress.databaseName;
          };
          themes = site.wordpress.themes;
          plugins = site.wordpress.plugins;
          languages = site.wordpress.languages;
          settings = {
            WP_DEFAULT_THEME = mkDefault "twentytwentythree";
            WP_SITEURL = "https://${site.siteFQDN}";
            WP_HOME = "https://${site.siteFQDN}";
            WPLANG = "pt_BR";
            AUTOMATIC_UPDATER_DISABLED = true;
            FORCE_SSL_ADMIN = true;
            WP_MAIL_FROM = mkDefault "gcp-devops@wcbrpar.com";
          } // site.wordpress.settings;
          
          # Configuração para o wp-config.php reconhecer o HTTPS vindo do proxy
          extraConfig = ''
            if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https') {
              $_SERVER['HTTPS'] = 'on';
            }
          '' + site.wordpress.extraConfig;

          poolConfig = site.wordpress.poolConfig;

          virtualHost = {
            addSSL = mkDefault false;
            listen = [ { addr = "0.0.0.0"; port = 7770; ssl = false; } ];
            
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

            # Configurações Nginx integradas
            locations = {
              "~* (.*\\.pdf)" = {
                extraConfig = ''
                  types { application/pdf .pdf; }
                  default_type application/pdf;
                  more_set_headers Content-Disposition "inline" always;
                  more_set_headers X-Content-Type-Options "nosniff";
                '';
              };
              # Sobrescreve a localização PHP padrão para garantir os headers de proxy
              "~ \\.php$" = {
                extraConfig = ''
                  fastcgi_pass unix:${config.services.phpfpm.pools."wordpress-${site.siteFQDN}".socket};
                  include ${pkgs.nginx}/conf/fastcgi.conf;
                  fastcgi_param HTTP_X_FORWARDED_PROTO $http_x_forwarded_proto;
                  fastcgi_param HTTP_X_FORWARDED_FOR $proxy_add_x_forwarded_for;
                '';
              };
            };
          };
        }
      ) enabledWpSites);

      services.phpfpm.pools = listToAttrs (mapAttrsToList (id: site:
        nameValuePair "wordpress-${site.siteFQDN}" {
          phpOptions = site.wordpress.phpOptions;
        }
      ) enabledWpSites);
    })

    # Configuração para sites estáticos (roda no pegasus)
    (lib.mkIf (config.networking.hostName == "pegasus") {
      services.nginx.virtualHosts = listToAttrs (mapAttrsToList (id: site:
        nameValuePair site.siteFQDN {
          forceSSL = mkDefault true;
          enableACME = mkDefault true;
          root = site.siteRoot;
          locations."/" = {
            index = "index.html index.htm";
            tryFiles = "$uri $uri/ =404";
          };
        }
      ) (filterAttrs (_: site: site.enable && site.siteType == "estatico") config.mkSite));
    })
  ]);
}


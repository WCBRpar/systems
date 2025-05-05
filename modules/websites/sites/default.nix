{ config, lib, pkgs, ... }:

let

  inherit (lib) mkOption mkEnableOption types mkIf filterAttrs mapAttrs' mkDefault;

  sources = import ../../../npins;
  wp4nix = pkgs.callPackage sources.wp4nix {};

  extractDomainRoot = fqdn:
    let
      parts = lib.splitString "." fqdn;
      root = if lib.length parts > 2 
        then lib.head parts
        else lib.elemAt parts (lib.length parts - 2);
    in
      lib.toLower root;

  # Funções auxiliares para opções condicionais
  mkWordPressOption = type: description: default:
    mkOption {
      type = type;
      default = default;
      description = description;
      visible = lib.mkDefault false;
    };

  mkStaticOption = type: description: default:
    mkOption {
      type = type;
      default = default;
      description = description;
      visible = lib.mkDefault false;
    };

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

        # Opções específicas para WordPress
        themes = mkWordPressOption 
          (types.attrsOf types.package) 
          "Temas WordPress" 
          {};

        plugins = mkWordPressOption 
          (types.attrsOf types.package) 
          "Plugins WordPress" 
          {};

        languages = mkWordPressOption 
          (types.listOf types.package) 
          "Pacotes de idiomas WordPress" 
          [wp4nix.languages.pt_BR];

        extraConfig = mkWordPressOption 
          types.lines 
          "Configurações extras do wp-config.php" 
          "";

        settings = mkWordPressOption 
          types.attrs 
          "Configurações adicionais" 
          {};

        # Opção específica para sites estáticos
        siteRoot = mkStaticOption
          types.path
          "Caminho raiz do conteúdo estático"
          "";
      };
      
      config = lib.mkMerge [
        {
          settings.WP_SITEID = mkDefault name;
        }
        (lib.mkIf (config.siteType == "wordpress") {
          themes.visible = true;
          plugins.visible = true;
          languages.visible = true;
          extraConfig.visible = true;
          settings.visible = true;
        })
        (lib.mkIf (config.siteType == "estatico") {
          siteRoot.visible = true;
        })
      ];
    }));
    default = {};
    description = "Sites configurados para servir";
  };

  config = lib.mkIf (
    config.networking.hostName == "pegasus" &&
    (builtins.length (filterAttrs (_: site: site.enable) config.mkSite) > 0)
  ) (lib.mkMerge [
    {
      services.wordpress.webserver = "nginx";
    }
    
    # Configuração para sites WordPress
    (lib.mkIf (lib.any (site: site.enable && site.siteType == "wordpress") (lib.attrValues config.mkSite)) {
      services.wordpress.sites = mapAttrs' (name: site: lib.mkIf (site.enable && site.siteType == "wordpress") {
        name = site.siteFQDN;
        value = {
          package = pkgs.wordpress;

          virtualHost = {
            hostName = site.siteFQDN;
            forceSSL = true;
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
                  fastcgi_pass unix:${config.services.phpfpm.pools."wordpress-${site.siteFQDN}".socket};

                  fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                  fastcgi_param HTTPS $http_x_forwarded_proto;
                  fastcgi_param HTTP_X_FORWARDED_PROTO $http_x_forwarded_proto;
                '';
              };
            };
          };

          settings = site.settings // {
            WP_SITEURL = "https://${site.siteFQDN}";
            WP_HOME = "https://${site.siteFQDN}";
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
            name = "wpdb_${extractDomainRoot site.siteFQDN}";
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
      }) config.mkSite;
    })
    
    # Configuração para sites estáticos
    (lib.mkIf (lib.any (site: site.enable && site.siteType == "estatico") (lib.attrValues config.mkSite)) {
      services.nginx.virtualHosts = lib.mapAttrs' (name: site: lib.mkIf (site.enable && site.siteType == "estatico") {
        name = site.siteFQDN;
        value = {
          forceSSL = true;
          enableACME = true;
          root = site.siteRoot;
          
          locations."/" = {
            index = "index.html index.htm";
            tryFiles = "$uri $uri/ =404";
          };
        };
      }) config.mkSite;
    })
  ]);
}

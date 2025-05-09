# modules/websites/sites/default.nix
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption types mkIf filterAttrs mapAttrs' mkDefault attrNames nameValuePair;
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

  countEnabledSites = sites:
    lib.length (lib.attrNames (lib.filterAttrs (_: site: site.enable) sites));

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

        # Opções para WordPress
        themes = mkOption {
          type = types.attrsOf types.package;
          default = {};
          description = "Temas WordPress";
          visible = lib.mkDefault (config.siteType == "wordpress");
        };

        plugins = mkOption {
          type = types.attrsOf types.package;
          default = {};
          description = "Plugins WordPress";
          visible = lib.mkDefault (config.siteType == "wordpress");
        };

        languages = mkOption {
          type = types.listOf types.package;
          default = [ wp4nix.languages.pt_BR ];
          description = "Pacotes de idiomas WordPress";
          visible = lib.mkDefault (config.siteType == "wordpress");
        };

        extraConfig = mkOption {
          type = types.lines;
          default = "";
          description = "Configurações extras do wp-config.php";
          visible = lib.mkDefault (config.siteType == "wordpress");
        };

        settings = mkOption {
          type = types.attrs;
          default = {};
          description = "Configurações adicionais";
          visible = lib.mkDefault (config.siteType == "wordpress");
        };

        # Opção para sites estáticos
        siteRoot = mkOption {
          type = types.path;
          description = "Caminho raiz do conteúdo estático";
          visible = lib.mkDefault (config.siteType == "estatico");
        };
      };
      
      config = lib.mkMerge [
        {
          settings.WP_SITEID = mkDefault name;
        }
      ];
    }));
    default = {};
    description = "Sites configurados para servir";
  };

  config = lib.mkIf (
    config.networking.hostName == "pegasus" &&
    (countEnabledSites config.mkSite) > 0
  ) (lib.mkMerge [
    {
      services.wordpress.webserver = "nginx";
    }
    
    # Configuração para sites WordPress
    (lib.mkIf (lib.any (site: site.enable && site.siteType == "wordpress") (lib.attrValues config.mkSite)) {
      services.wordpress.sites = 
        let
          enabledSites = lib.filterAttrs (_: site: site.enable && site.siteType == "wordpress") config.mkSite;
        in
          lib.listToAttrs (lib.mapAttrsToList (_: site:
            lib.nameValuePair site.siteFQDN {
              package = pkgs.wordpress;
              # ... (restante da configuração WordPress)
            }
          ) enabledSites);
    })
    
    # Configuração para sites estáticos
    (lib.mkIf (lib.any (site: site.enable && site.siteType == "estatico") (lib.attrValues config.mkSite)) {
      services.nginx.virtualHosts = 
        let
          enabledSites = lib.filterAttrs (_: site: site.enable && site.siteType == "estatico") config.mkSite;
        in
          lib.listToAttrs (lib.mapAttrsToList (_: site:
            lib.nameValuePair site.siteFQDN {
              forceSSL = true;
              enableACME = true;
              root = site.siteRoot;
              locations."/" = {
                index = "index.html index.htm";
                tryFiles = "$uri $uri/ =404";
              };
            }
          ) enabledSites);
    })
  ]);
}

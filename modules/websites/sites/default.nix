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

  # Função corrigida para opções condicionais
  mkWordPressOption = type: description: default:
    mkOption {
      type = type;
      default = default;
      description = description;
      visible = lib.mkDefault false;
    };

  # Versão corrigida de mkStaticOption
  mkStaticOption = type: description: default:
    let
      baseOption = mkOption {
        type = type;
        default = default;
        description = description;
      };
    in
      lib.mkMerge [
        baseOption
        { visible = lib.mkDefault false; }
      ];

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

        # Agora funcionará corretamente com strings ou paths
        siteRoot = mkStaticOption
          (types.either types.path types.str)
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

  # ... (restante do arquivo permanece igual)
}

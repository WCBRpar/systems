{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption types mkIf filterAttrs mapAttrs' mkDefault attrNames;
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

  # Função para contar sites ativos (corrigida)
  countEnabledSites = sites:
    lib.length (lib.attrNames (lib.filterAttrs (_: site: site.enable) sites));

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

        # ... (restante das opções permanece igual)
      };
      
      # ... (restante da configuração permanece igual)
    }));
    default = {};
    description = "Sites configurados para servir";
  };

  config = lib.mkIf (
    config.networking.hostName == "pegasus" &&
    (countEnabledSites config.mkSite) > 0
  ) (lib.mkMerge [
    # ... (restante da configuração permanece igual)
  ]);
}

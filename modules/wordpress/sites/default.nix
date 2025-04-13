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

in 

{
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
      name = site.domain;  # Mantém o domínio completo sem modificações
      value = {
        package = pkgs.wordpress;

        virtualHost = {
          hostName = site.domain;
	  useACMEHost = site.domain;
          forceSSL = true;
          enableACME = true;
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
	  sslServerCert = "null";
	  sslServerKey = "null";
        }
	// (site.settings.virtualHost or {});

        settings = (site.settings or {}) // {
          poolConfig = ''
            pm = dynamic
            pm.max_children = 64
            pm.max_requests = 500
            pm.max_spare_servers = 4
            pm.min_spare_servers = 2
            pm.start_servers = 2
          '';
        };

        database = {
          name = "wpdb_${extractDomainRoot site.domain}";  # Mantido exatamente como estava
          host = "localhost";
          createLocally = true;
        };

        themes = site.themes;
        plugins = site.plugins;
        languages = site.languages;

        extraConfig = ''
          define('WPLANG', 'pt_BR');
          ${site.extraConfig}
        '';
      };
    }) config.wp-sites;
  };
}

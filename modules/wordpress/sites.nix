# Este módulo provê uma configurção melhor estruturada para 
# conteineres wordpress utilizando nginx e 
# o módulo web-apps/wordpress

{ options, config, lib, pkgs, ...}:

with lib;

let 

  inherit (lib) concatStringsSep mkIf mkOption optionalString types;
  
  cfg = config.services.wp-sites;

in {

  options.services.wp-sites = mkOption {
    name = mkOption {
      type = types.str;
      example = "SITE";
      description = "Nome do Acrônimo do site";
    };
    domain = mkOption {
      type = types.str;
      example = "site.example.com";
      description = "Endereço web do site a ser implementado";
    };
    organization = mkOption {
      type = types.str;
      example = "organization.com";
      description = "Organização de nível superior, caso haja";
      default = cfg.services.wp-sites.domain;
    };
    siteType = mkOption {
      type = types.enum [ "wordpress" "www" ];
      example = "wordpress or www";
      description = "Tipo de implmentação do site";
    };
    wordpress.plugins = mkOption {
      type = types.listOf str;
      example = "co-authors-plus \n google-site-kit";
      description = "Plugins do WordPress a serem instalados";
    }
    wordpress.themes = mkOptions {
      type = types.listOf str;
      example = "astra \n twentytwentythree";
      description = "Temas do WordPRess a serem instalados";
    };
  };

  config = {
    security.acme = {
      certs."${cfg.services.wp-sites.organization}"= {
        extraDomainsNames = [ "*.${cfg.services.wp-sites.doman}" ];
	webroot = "/var/lib/acme/${cfg.services.wp-sites.organization}";
	group = "nginx";
      };
    };

    services = {
      phpfpm.pools."wordpress-$cfg.services.wp-sites.domain}".phpOptions = ''
        upload_max_filesize = 128M
	post_max_size = 128M
	memory_limit = 256M
      '';

      wordpress = {
        webserver = "nginx";
	sites = {
	  "${cfg.services.wp-sites.domain}"= {
	    package = pkgs.wordpress6_4;
	    database = {
	      createLocally = true;
	      name = "wpdb_${cfg.services.wp-sites.name}";
	    };
	    plugins = { 
	      inherit (wp4nix.plugins) ${cfg.services.wp-sites.name.wordpress.plugins};
	    }; 
	    themes = {
	      inherit (wp4nix.themes) ${cfg.services.wp-sites.name.wordpress.themes};
	    };
	    #LANGUAGE - ADICIONAR
            poolConfig = {
	      "pm"= "dynamic";
	      "pm.max_children"= 64;
	      "pm.max_requests"= 500;
              "pm.max_spare_servers"= 4;
	      "pm.min_spare_servers"= 2;
	      "pm.start_servers"= 2; 
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
	    };
	    addSSL = false;
          };
        };
      };

    };

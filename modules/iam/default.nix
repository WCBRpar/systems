{ config, lib, pkgs, ... }:

{

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 636 ];
  };

  environment.systemPackages = with pkgs; [ kanidm nginx ];

  services.traefik.dynamicConfigOptions = {
    http = {
      routers = {
        iam = {
          rule = "Host(`iam.wcbrpar.com`)";
          service = "kanidm-service";
          entrypoints = ["websecure"];
          tls.certResolver = "cloudflare";
          # Adicione isto para evitar loops:
          middlewares = ["fix-kanidm-headers"];
        };
      };

      services = {
        kanidm-service = {
          loadBalancer = {
            servers = [{ url = "https://localhost:8443"; }];
            # Importante para lidar com redirecionamentos:
            passHostHeader = true;
          };
        };
      };

      middlewares = {
        "strip-prefix" = {
          stripPrefix = {
            prefixes = ["/ui"];
            forceSlash = false;
          };
	  "fix-kanidm-headers" = {
	    headers = {
	      customRequestHeaders = {
	        X-Forwarded-Proto = "https";
		X-Real-IP = "$remote_addr";
	      };
	    sslRedirect = false;
	    };
	  };
        };
      };
    };
  };

  services.kanidm = {
    enableClient = true;

    # Configurações do cliente Kanidm (usando objeto Nix)
    clientSettings = {
      uri = "https://iam.wcbrpar.com:8443";
      verify_ca = true;
      verify_hostnames = true;

      # Configurações adicionais (opcional)
      name = {
        uri = "https://iam.redcom.digital";
      };
    };

    enableServer = lib.mkIf ( config.networking.hostName == "galactica" ) true;
    serverSettings = lib.mkIf ( config.networking.hostName == "galactica" ) {
      domain = "wcbrpar.com";
      origin = "https://iam.wcbrpar.com";
      bindaddress = "127.0.0.1:8443";
      ldapbindaddress = "127.0.0.1:636";
      tls_chain = "/var/lib/acme/wcbrpar.com/cert.pem";
      tls_key = "/var/lib/acme/wcbrpar.com/key.pem";
    };

    unixSettings = lib.mkIf ( config.networking.hostName == "galactica" ) {
      hsm_type = "soft";
      default_shell = "/bin/zsh";
      home_attr = "uuid";
      home_prefix = "/home/";
      pam_allowed_login_groups = [ "users" "admins" ];
    };

    enablePam = lib.mkIf ( config.networking.hostName == "galactica" ) true;

    provision = lib.mkIf ( config.networking.hostName == "galactica" ) {
      enable = true;
      autoRemove = true;

      groups = {
        "admins" = { };
        "users" = { };
      };

      persons = {
        "wjjunyor" = {
          displayName = "WQJ";
          legalName = "Walter Queiroz Jr";
          mailAddresses = [ "walter@wcbrpar.com" ];
          groups = [ "admins" "users" ];
        };
      };
    };
  };

  users.users.kanidm.extraGroups = [ "traefik" "acme" "nginx" ];
}

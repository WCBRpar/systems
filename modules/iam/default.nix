{ config, lib, pkgs, ... }:

{

  networking.firewall = lib.mkIf ( config.networking.hostName == "galactica" ) {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
    allowedTCPPortRanges = [
      { from = 80; to = 443; }
    ];
    extraCommands = ''
      iptables -A INPUT -p tcp --dport 8443 -s 127.0.0.1 -j ACCEPT
      iptables -A INPUT -p tcp --dport 8443 -j DROP
    '';
  };

  environment.systemPackages = with pkgs; [ kanidm nginx ];

  services.traefik.dynamicConfigOptions = lib.mkIf ( config.networking.hostName == "galactica" ) {
    http = {
      routers = {
        KN-ALL = {
	  rule = "Host(`iam.wcbrpar.com`) && (PathPrefix(`/`))";
          service = "kanidm-service";
          entrypoints = ["websecure"];
          tls = {
	    certResolver = "cloudflare";
	  };
          middlewares = ["fix-kanidm-headers" ];

        };
      };

      services = {
        kanidm-service = {
          loadBalancer = {
            servers = [{ url = "${toString config.services.kanidm.serverSettings.origin}:8443"; }];
            # Importante para lidar com redirecionamentos:
            passHostHeader = true;
          };
        };
      };



      middlewares = {
        "fix-kanidm-headers" = {
          headers = {
            customRequestHeaders = {
              X-Forwarded-Proto = "https";
	            X-Forwarded-Host = "iam.wcbrpar.com";
              X-Real-IP = "$remote_addr";
            };
            sslRedirect = false;
          };
        };
        "strip-kanidm-prefix" = {
          stripPrefix = {
            prefixes = ["/ui"];
            forceSlash = false;
          };
        };
      };

    };
  };

  services.kanidm = {
    enableClient = true;
    package = pkgs.kanidm_1_7;

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
      bindaddress = "0.0.0.0:8443";
      ldapbindaddress = "0.0.0.0:636";
      tls_chain = "/var/lib/acme/wcbrpar.com/cert.pem";
      tls_key = "/var/lib/acme/wcbrpar.com/key.pem";
    };

    unixSettings = lib.mkIf ( config.networking.hostName == "galactica" ) {
      hsm_type = "soft";
      default_shell = "/bin/zsh";
      home_attr = "uuid";
      home_prefix = "/home/";
      kanidm.pam_allowed_login_groups = [ "users" "admins" ];
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

  users.users.kanidm.isSystemUser = true;
  users.users.kanidm.extraGroups = [ "traefik" "acme" "nginx" ];
  users.users.kanidm.group = "kanidm";
  users.groups.kanidm = {};

}

{ config, lib, pkgs, ... }:

{
  networking.firewall = lib.mkIf (config.networking.hostName == "galactica") {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
    # Allow Kanidm API (OIDC) and LDAPS for other hosts
    allowedTCPPorts = [ 80 443 8443 636 ];
    # The extraCommands are no longer needed because we now include 8443 in allowedTCPPorts
    # If you want to restrict access to a specific subnet, use allowedTCPPortRanges instead.
    # Example: allowedTCPPortRanges = [ { from = 8443; to = 8443; } ] combined with
    # firewall.extraCommands = "iptables -A INPUT -p tcp --dport 8443 -s 192.168.1.0/24 -j ACCEPT";
    extraCommands = "";
  };

  environment.systemPackages = with pkgs; [ kanidm_1_9 nginx ];

  services.traefik.dynamicConfigOptions = lib.mkIf (config.networking.hostName == "galactica") {
    http = {
      routers = {
        KN-ALL = {
          rule = "Host(`iam.wcbrpar.com`) || Host(`iam.redcom.digital`) && (PathPrefix(`/`))";
          service = "kanidm-service";
          entrypoints = ["websecure"];
          tls = {
            certResolver = "cloudflare";
          };
          middlewares = ["fix-kanidm-headers"];
        };
      };

      services = {
        kanidm-service = {
          loadBalancer = {
            servers = [{ url = "${toString config.services.kanidm.serverSettings.origin}:8443"; }];
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
    package = pkgs.kanidm_1_9;

    client = {
      enable = true;
      settings = {
        uri = "https://iam.wcbrpar.com:8443";
        verify_ca = true;
        verify_hostnames = true;
      };
    };

    server = lib.mkIf (config.networking.hostName == "galactica") {
      enable = true;
      settings = {
        domain = "wcbrpar.com";
        origin = "https://iam.wcbrpar.com";
        bindaddress = "0.0.0.0:8443";
        ldapbindaddress = "0.0.0.0:636";
        tls_chain = "/var/lib/acme/wcbrpar.com/cert.pem";
        tls_key = "/var/lib/acme/wcbrpar.com/key.pem";

        # OAuth2 clients for web services – uncomment and customise as needed
        # oauth2 = {
        #   "traefik" = {
        #     client_id = "traefik";
        #     client_secret = "CHANGE_ME";  # use a secret manager!
        #     redirect_uris = [ "https://example.com/oauth2/callback" ];
        #     response_types = [ "code" ];
        #     scopes = [ "openid" "profile" "email" ];
        #   };
        # };
      };
    };

    unix = {
      settings = {
        hsm_type = "soft";
        default_shell = "/bin/zsh";
        home_attr = "uuid";
        home_prefix = "/home/";
        kanidm.pam_allowed_login_groups = [ "users" "admins" ];
      };
    };

    enablePam = lib.mkIf (config.networking.hostName == "galactica") true;

    provision = lib.mkIf (config.networking.hostName == "galactica") {
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

  users.users.kanidm = {
    isSystemUser = true;
    extraGroups = [ "traefik" "acme" "nginx" ];
    group = "kanidm";
  };
  users.groups.kanidm = { };
}

{ config, lib, pkgs, ... }:

{
  networking.firewall = lib.mkIf (config.networking.hostName == "galactica") {
    enable = true;
    allowedTCPPorts = [ 80 443 8443 636 ];
    extraCommands = "
      iptables -A INPUT -p tcp --dport 8443 -j ACCEPT
    ";
  };

  environment.systemPackages = with pkgs; [ kanidm_1_9 nginx ];

  services.traefik = {

    dynamicConfigOptions = lib.mkIf (config.networking.hostName == "galactica") {
      http = {
        serversTransports = {
          kanidm-backend = {
            insecureSkipVerify = true;
          };
        };
        routers = {
          KN-ALL = {
            rule = "Host(`iam.wcbrpar.com`) || Host(`iam.redcom.digital`)";
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
              servers = [{ url = "https://galactica.wcbrpar.com:8443"; }];
              passHostHeader = true;
              serversTransport = "kanidm-backend";
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
  };

  services.kanidm = {
    package = pkgs.kanidm_1_9;

    client = {
      enable = true;
      settings = {
        uri = "https://iam.wcbrpar.com";
        verify_ca = false;
        verify_hostnames = false;
      };
    };

    server = lib.mkIf (config.networking.hostName == "galactica") {
      enable = true;
      settings = {
        domain = "wcbrpar.com";
        origin = "https://iam.wcbrpar.com";
        bindaddress = "0.0.0.0:8443";
        ldapbindaddress = "0.0.0.0:636";
        tls_chain = "/var/lib/acme/iam.wcbrpar.com/cert.pem";
        tls_key = "/var/lib/acme/iam.wcbrpar.com/key.pem";
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

      systems = {
        oauth2 = {
          "traefik" = {
            # Atributos essenciais do cliente
            displayName = "Traefik Dashboard";
            originUrl = "https://traefik.wcbrpar.com/oidc/callback";
          
            # Define como um cliente público (usando PKCE)
            public = true;
          
            # Mapeia os scopes padrão do OIDC
            scopeMaps = {
              "openid" = [ "authenticated" ];
              "profile" = [ "authenticated" ];
              "email" = [ "authenticated" ];
            };
          };
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

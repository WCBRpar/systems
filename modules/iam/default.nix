{ config, lib, pkgs, ... }:

{
  networking.firewall = lib.mkIf (config.networking.hostName == "galactica") {
    enable = true;
    allowedTCPPorts = [ 80 443 8443 636 ];
    extraCommands = "";
  };

  environment.systemPackages = with pkgs; [ kanidm_1_9 nginx ];

  services.traefik = {
    staticConfigOptions = {
      serversTransports = {
        skipverify-transport = {
          insecureSkipVerify = true;
        };
      };
    };

    dynamicConfigOptions = lib.mkIf (config.networking.hostName == "galactica") {
      http = {
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
              serversTransport = "skipverify-transport";
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
      };
    };

    unix = {
      settings = {
        hsm_type = "soft";
        default_shell = "/bin/zsh";
        home_attr = "uuid";
        home_prefix = "/home/";
        kanidm.pam_allowed_login_groups = [ "users" "admins" ];
        enablePam = lib.mkIf (config.networking.hostName == "galactica") true;
      };
    };

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

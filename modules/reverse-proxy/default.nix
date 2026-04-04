{
  config,
  lib,
  pkgs,
  hostName,
  ...
}: {


  #Segredos Necessários para o funcinamento
    age.secrets = {
    # Client secret para API da Cloudflare
    cloudflare-api-key = {
      file = ../../secrets/cloudflareApiKey.age;
      mode = "600";
      owner = "traefik";
      group = "traefik";
    };
  };


  services.traefik = lib.mkIf (hostName == "galactica") {
    enable = true;
    dataDir = "/var/lib/traefik"; # Diretório para dados persistentes do Traefik (como acme.json)
    environmentFiles = [ 
      config.age.secrets.cloudflare-api-key.path 
    ];
    group = "nginx";

    staticConfigOptions = {
      log = {
        level = "INFO"; 
        filePath = "/var/log/traefik/traefik.log"; # Logs do Traefik
      };

      # Access Logs
      accessLog = {
        filePath = "/var/log/traefik/access.log";
        format = "json"; # Pode ser "common" ou "json"
        bufferingSize = 100;
        filters = {
          statusCodes = ["200-299" "300-399" "400-499" "500-599"];
          retryAttempts = true;
          minDuration = "10ms";
        };
      };

      # Métricas (Prometheus)
      metrics = {
        prometheus = {
          entryPoint = "metrics";
          addServicesLabels = true;
          addEntryPointsLabels = true;
          addRoutersLabels = true;
        };
      };

      tracing = {
        otlp = {
          http = {
            endpoint = "http://localhost:4318";
          };
        };
      };

      api = {
        dashboard = true;
        insecure = false; # Dashboard protegido por middleware OIDC
      };
      
      experimental = {
        plugins = {
          "traefik-oidc-auth" = {
            moduleName = "github.com/sevensolutions/traefik-oidc-auth";
            version = "v0.18.0";
          };
        };
      };
      
      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entryPoint = {
            to = "websecure";
            scheme = "https";
            permanent = false;
          };
        };

        websecure = {
          address = ":443";
          http.tls = {
            certResolver = "cloudflare";
            options = "mytls";
          };
        };

        metrics = {
          address = ":8082";
        };
      };

      certificatesResolvers = {
        cloudflare = {
          acme = {
            email = "dev-ops@wcbrpar.com";
            storage = "/var/lib/traefik/acme.json";
            dnsChallenge = {
              provider = "cloudflare";
              resolvers = ["1.1.1.1:53" "8.8.8.8:53"];
              propagation.delayBeforeChecks = 120; # Important: Increase delay for slow DNS propagation
            };
          };
        };
      };
    };

    dynamicConfigOptions = {
      http = {
        routers = {
          TK-WPR = {
            rule = "Host(`traefik.wcbrpar.com`)";
            service = "api@internal";
            entrypoints = ["websecure"];
            tls = {
              certResolver = "cloudflare";
            };
            middlewares = [ "dashboard-redirect" "oidc-auth" ];
          };

          metrics = {
            rule = "Host(`traefik.wcbrpar.com`) && PathPrefix(`/metrics`)";
            service = "prometheus@internal";
            entrypoints = ["websecure"];
            tls.certResolver = "cloudflare";
          };
        };
        
        middlewares = {
          "dashboard-redirect" = {
            redirectRegex = {
              regex = "^https://traefik.wcbrpar.com$";
              replacement = "https://traefik.wcbrpar.com/dashboard/";
              permanent = true;
            };
          };
          
          "oidc-auth" = lib.mkIf (hostName == "galactica") {
            plugin = {
              "traefik-oidc-auth" = {
                # URL de callback correta
                SessionCookieName = "_oauth2_proxy";
                OauthStartPath = "/oauth2/start";
                OauthCallbackPath = "/oauth2/callback";
                
                Scopes = [ "openid" "profile" "email" "groups" ];
                Provider = {
                  Url = "https://iam.wcbrpar.com/oauth2/openid/traefik-dashboard/.well-known/openid-configuration";
                  ClientId = "traefik-dashboard";
                  UsePkce = true; 
                  InsecureSkipVerifyTls = false;
                };
                
                # Validação de claims/grupos
                Authorization = {
                  AssertClaims = [
                    {
                      Name = "groups"; # Nome da claim que será verificada
                      AnyOf = [ "admin-tools" ]; # Valor que ela deve conter
                    }
                  ];
                };
                
                # Headers para passar informações do usuário
                Headers = {
                  Request = {
                    Set = {
                      X-Forwarded-User = "{user}";
                      X-Forwarded-Groups = "{groups}";
                      X-Forwarded-Email = "{email}";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  # Configuração OAuth2 do Kanidm para o Traefik Dashboard
  services.kanidm.provision.systems.oauth2 = lib.mkIf (hostName == "galactica") {
    "traefik-dashboard" = {
      displayName = "Traefik Dashboard";
      originUrl = "https://traefik.wcbrpar.com";
      originLanding = "https://traefik.wcbrpar.com";
      public = false;
      
    };
  };

  networking.firewall.allowedTCPPorts = [80 443];

  # Garante que os diretórios existam
  systemd.tmpfiles.rules = [
    "d /var/lib/traefik 0750 traefik traefik -"
    "f /var/lib/traefik/acme.json 0750 traefik traefik -"
    "d /var/log/traefik 0750 traefik traefik -"
    "f /var/log/traefik/access.log 0750 traefik traefik -"
  ];

  # Configuração de rotação de logs
  services.logrotate.settings.traefik = {
    files = ["/var/log/traefik/*.log"];
    frequency = "daily";
    rotate = 7;
    compress = true;
    missingok = true;
    copytruncate = true;
  };
}

{
  config,
  lib,
  ...
}: {
  services.traefik = lib.mkIf (config.networking.hostName == "galactica") {
    enable = true;
    dataDir = "/var/lib/traefik"; # Diretório para dados persistentes do Traefik (como acme.json)
    environmentFiles = ["/var/lib/cloudflare/cloudflare.s"];
    group = "nginx";

    staticConfigOptions = {
      log = {
        level = "DEBUG";
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

      # Tracing (OpenTelemetry)
      tracing = {
        otlp = {
          http = {
            endpoint = "http://localhost:4318";
          };
        };
      };

      api = {
        dashboard = true;
        insecure = true; # CUIDADO: Permite acesso ao dashboard sem autenticação na porta 8080.
        # Para produção, você DEVE proteger o dashboard.
        # Veja a seção de proteção do dashboard abaixo.
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
            # cipherSuites = [
            #   "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
            #   "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
            # ];
            # minVersion = "VersionTLS12";
            # sniStrict = true;
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
            # caserver = "https://acme-v02.api.letsencrypt.org/directory";
            dnsChallenge = {
              provider = "cloudflare";
              # credentialsFile = "/var/lib/cloudflare/cloudflare.s"; # Caminho corrigido
              resolvers = ["1.1.1.1:53" "8.8.8.8:53"];
              propagation.delayBeforeChecks = 120; # Important: Increase delay for slow DNS propagation
            };
          };
        };
      };

      # Cloudflare WildCard
      cloudflare-wildcard = {
        acme = {
          email = "dev-ops@wcbrpar.com";
          storage = "/var/lib/traefik/acme-wildcard.json";
          dnsChallenge = {
            provider = "cloudflare";
            resolvers = ["1.1.1.1:53"];
          };
          # Configuração específica para wildcard
          keyType = "RSA4096";
        };
      };
    };

    dynamicConfigOptions = {
      http = {
        routers = {
          TK-DASHBOARD = {
            rule = "Host(`traefik.wcbrpar.com`) || Host(`traefik.redcom.digital`) && (PathPrefix(`/`) || PathPrefix(`/dashboard`) || PathPrefix(`/api`))";
            service = "api@internal";
            entrypoints = ["websecure"];
            tls = {
              certResolver = "cloudflare";
            };
            # IMPLEMENTAR MIDDLEWARE W/ KANIDM ***************
            middlewares = ["dashboard-redirect"];
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
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [80 443];

  # Garante que o diretório de challenges exista
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

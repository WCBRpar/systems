{ config, lib, ...}:

{
  services.traefik = lib.mkIf ( config.networking.hostName == "galactica" ) {
    enable = true;
    dataDir = "/var/lib/traefik";	    # Diretório para dados persistentes do Traefik (como acme.json)
    environmentFiles = [ "/var/lib/cloudflare/cloudflare.s" ];
    group = "nginx";

    staticConfigOptions = {
      log = {
        level = "DEBUG";
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
    };

    dynamicConfigOptions = {
      http = {
        routers = {
          dashboard = {
	    rule = "Host(`traefik.wcbrpar.com`) && (PathPrefix(`/`) || PathPrefix(`/dashboard`) || PathPrefix(`/api`))";
            service = "api@internal";
            entrypoints = ["websecure"];
            tls = {
              certResolver = "cloudflare";
            };
	    # IMPLEMENTAR MIDDLEWARE W/ KANIDM ***************
	    middlewares = ["dashboard-redirect"];
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
  ];
}


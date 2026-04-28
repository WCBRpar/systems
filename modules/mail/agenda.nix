{ config, pkgs, lib, hostName, ... }:

{
  # Radicale CalDAV/CardDAV com autenticação LDAP
  services.radicale = lib.mkIf ( hostName == "galactica" ) {
    enable = true;
    # user = "radicale";
    # group = "radicale";
    settings = {
      auth = {
        # Usando autenticação por header para integrar com o Traefik OIDC
        type = "http_remote_user";
        # remote_user_variable = "X-Forwarded-User";
        # type = "ldap";
        # ldap_uri = "ldaps://ldap.wcbrpar.com";
        # ldap_base = "dc=wcbrpar,dc=com";
        # # Filtro para o Kanidm
        # ldap_filter = "(mail=%u)";
        # # Opções de bind para o plugin LDAP do Radicale (formato atual)
        # ldap_reader_dn = "spn=mail_bind@wcbrpar.com";
        # ldap_secret_file = config.age.secrets.ldap-mail-password.path;
      };
      server = {
        hosts = [ "127.0.0.1:5232" "[::1]:5232" ];
      };
      storage = {
        filesystem_folder = "/var/lib/radicale/collections";
        type = "multifilesystem";
      };
    };
  };
  
  # Permitir que o radicale acesse o segredo do agenix
  users.groups.snm = {};
  users.groups.radicale = {};
  users.users.radicale = {
    isSystemUser = true;
    group = "radicale";
    extraGroups = [ "traefik" "acme" "snm" ];
  };

  # Rotas Traefik para Radicale
  services = { 
    traefik = lib.mkIf ( hostName == "galactica" ) {
      dynamicConfigOptions = {
        http = {
          routers = {
            AG-ALL = {
              rule = "Host(`cal.wcbrpar.com`) || Host(`cal.redcom.digital`) || Host(`cal.walcor.com.br`) || Host(`cal.wqueiroz.adv.br`)";
              service = "radicale-service";
              entrypoints = [ "websecure" ];
              # Aplicando o middleware de autenticação OIDC do Kanidm
              middlewares = [ "oidc-auth-radicale" ];
              tls = {
                certResolver = "cloudflare";
              };
            };
          };
          services = {
            radicale-service = {
              loadBalancer = {
                servers = [{ url = "http://127.0.0.1:5232"; }];
                passHostHeader = false;
              };
            };
          };
          middlewares = {
            "oidc-auth-radicale" = {
              plugin = {
                "traefik-oidc-auth" = {
                  SessionCookieName = "_radicale_session";
                  OauthStartPath = "/oauth2/start";
                  OauthCallbackPath = "/oidc/callback";
                  
                  Scopes = [ "openid" "profile" "email" "groups" ];
                  Provider = {
                    Url = "https://iam.wcbrpar.com/oauth2/openid/radicale/";
                    ClientId = "radicale";
                    UsePkce = true; 
                    InsecureSkipVerifyTls = false;
                  };
                  
                  ClaimMappings = {
                    # Mapeia o e-mail ou username para o header que o Radicale vai ler
                    Email = "mail_primary";
                  };
                  
                  LogLevel = "debug";
                  
                  # Headers para passar o usuário autenticado para o Radicale
                  Headers = {
                    Request = {
                      Set = {
                        X-Remote-User = "{email}";
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

    # Configuração OAuth2 do Kanidm para o Radicale (Centralizada aqui)
    kanidm.provision.systems.oauth2 = lib.mkIf (hostName == "galactica") {
      "radicale" = {
        displayName = "Radicale Agenda";
        originUrl = [
          "https://cal.wcbrpar.com/oidc/callback"
          "https://cal.redcom.digital/oidc/callback"
          "https://cal.walcor.com.br/oidc/callback"
          "https://cal.wqueiroz.adv.br/oidc/callback"
        ];
        originLanding = "https://cal.wcbrpar.com/";
        imageFile = ../../media-assets/iam-auth-badges/radicale-auth.svg;
        public = true;
        scopeMaps = {
          "users" = [ "openid" "profile" "email" "groups" ];
        };
      };
    };
  };
}

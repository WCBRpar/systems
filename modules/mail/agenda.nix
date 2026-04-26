{ config, pkgs, lib, hostName, ... }:

{
  # Radicale CalDAV/CardDAV com autenticação LDAP
  services.radicale = lib.mkIf ( hostName == "galactica" ) {
    enable = true;
    # user = "radicale";
    # group = "radicale";
    settings = {
      auth = {
        type = "ldap";
        ldap_uri = "ldaps://ldap.wcbrpar.com";
        ldap_base = "dc=wcbrpar,dc=com";
        # Filtro para o Kanidm
        ldap_filter = "(mail=%u)";
        # Opções de bind para o plugin LDAP do Radicale (formato atual)
        ldap_reader_dn = "spn=mail_bind@wcbrpar.com";
        ldap_secret_file = config.age.secrets.ldap-mail-password.path;
      };
      server = {
        hosts = [ "127.0.0.1:5232" "[::1]:5232" ];
      };
      storage = {
        filesystem_folder = "/var/lib/radicale/collections";
      };
    };
  };
  
  # Permitir que o radicale acesse o segredo do agenix
  users.groups.snm = {};
  users.users.radicale = {
    isSystemUser = true;
    group = "radicale";
    extraGroups = [ "traefik" "acme" "snm" ];
  };

  # Rotas Traefik para Radicale
  services.traefik = lib.mkIf ( hostName == "galactica" ) {
    dynamicConfigOptions = {
      http = {
        routers = {
          CAL-ALL = {
            rule = "Host(`cal.wcbrpar.com`) || Host(`cal.redcom.digital`) || Host(`cal.walcor.com.br`) || Host(`cal.wqueiroz.adv.br`)";
            service = "radicale-service";
            entrypoints = [ "websecure" ];
            tls = {
              certResolver = "cloudflare";
            };
          };
        };
        services = {
          radicale-service = {
            loadBalancer = {
              servers = [{ url = "http://127.0.0.1:5232"; }];
              passHostHeader = true;
            };
          };
        };
      };
    };
  };
}

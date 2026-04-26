{ config, pkgs, lib, hostName, ... }:

{
  # Radicale CalDAV/CardDAV com autenticação LDAP
  services.radicale = lib.mkIf ( hostName == "galactica" ) {
    enable = true;
    settings = {
      auth = {
        type = "ldap";
        ldap_uri = "ldaps://ldap.wcbrpar.com";
        ldap_base = "dc=wcbrpar,dc=com";
        # Filtro para o Kanidm
        ldap_filter = "(mail=%u)";
        # Opções padrão para o plugin LDAP do Radicale
        ldap_bind_dn = "spn=mail_bind@wcbrpar.com";
        ldap_bind_pw_file = config.age.secrets.ldap-mail-password.path;
      };
      server = {
        hosts = [ "127.0.0.1:5232" "[::1]:5232" ];
      };
      storage = {
        filesystem_folder = "/var/lib/radicale/collections";
      };
    };
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

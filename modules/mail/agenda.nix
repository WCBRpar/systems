{ config, pkgs, lib, ... }:

{
  # Radicale CalDAV/CardDAV com autenticação LDAP
  services.radicale = lib.mkIf ( config.networking.hostName == "galactica" ) {
    enable = true;
    settings = {
      auth = {
        type = "ldap";
        ldap_uri = "ldaps://ldap.wcbrpar.com";
        ldap_base = "dc=wcbrpar,dc=com";
        # Kanidm: objectClass=account, bind via spn
        ldap_filter = "(&(objectClass=account)(uid=%u))";
        ldap_bind_dn = "spn=mail_bind@wcbrpar.com";
        ldap_bind_pw_file = "/run/agenix/ldap-mail-password";
        ldap_use_ssl = true;
      };
      server = {
        hosts = [ "127.0.0.1:5232" "[::1]:5232" ];
      };
      storage = {
        filesystem_folder = "/var/lib/radicale/collections";
      };
    };
  };
  
  # Rotas Traefik para Radicale (substitui Nginx)
  services.traefik = lib.mkIf ( config.networking.hostName == "galactica" ) {
    dynamicConfigOptions = {
      http = {
        routers = {
          CAL-ALL = {
            rule = "Host(`cal.wcbrpar.com`) || host(`cal.redcom.digital`) || Host(`cal.walcor.com.br`) || Host(`cal.wqueiroz.adv.br`)";
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

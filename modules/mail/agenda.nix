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
        # Kanidm: objectClass=account, bind via spn
        ldap_filter = "(&(objectClass=account)(uid=%u))";
        # Correção: Radicale usa nomes de opções sem o prefixo 'ldap_' para sub-opções em algumas versões
        # ou nomes específicos como 'bind_dn' e 'bind_pw'
        bind_dn = "spn=mail_bind@wcbrpar.com";
        bind_pw_file = config.age.secrets.ldap-mail-password.path;
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

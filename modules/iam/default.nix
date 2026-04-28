{ config, lib, pkgs, hostName, ... }:

{
  networking.firewall = lib.mkIf (hostName == "galactica") {
    enable = true;
    allowedTCPPorts = [ 80 443 636 8443 ];
    extraCommands = ''
      # Remove qualquer regra DROP existente na porta 8443 (ignora se não existir)
      # iptables -D INPUT -p tcp --dport 8443 -j DROP 2>/dev/null || true
      # Garante acesso irrestrito à porta 8443 (já incluída no allowedTCPPorts, mas por segurança)
      # iptables -A INPUT -p tcp --dport 8443 -j ACCEPT
    '';
  };
  
  environment.systemPackages = with pkgs; [ kanidm_1_9 nginx ];
  
  # Configuração do Traefik para proxy reverso do Kanidm
  services.traefik.dynamicConfigOptions = lib.mkIf (hostName == "galactica") {
    http = {
      serversTransports = {
        kanidm-backend = {
          insecureSkipVerify = true; # Kanidm rodando sem TLS localmente
        };
      };
      routers = {
        KN-WPR = {
          rule = "Host(`iam.wcbrpar.com`) || Host(`iam.redcom.digital`)";
          service = "kanidm-service";
          entrypoints = ["websecure"];
          tls = {
            certResolver = "cloudflare";
          };
          middlewares = ["kanidm-headers"];
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
        "kanidm-headers" = {
          headers = {
            customRequestHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "{host}";
              X-Real-IP = "$remote_addr";
              X-Forwarded-For = "$proxy_add_x_forwarded_for";
            };
            sslRedirect = false;
            # Headers de segurança importantes
            stsSeconds = 31536000;
            stsIncludeSubdomains = true;
            stsPreload = true;
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
        verify_ca = false;
        verify_hostnames = false;
      };
    };
    
    server = lib.mkIf (hostName == "galactica") {
      enable = true;
      settings = {
        log_level = "debug";
        domain = "wcbrpar.com";
        origin = "https://iam.wcbrpar.com";
        # Manter 0.0.0.0 pois mesmo o traefik fazendo o  proxy, os hosts se cumunicam internamente sem proxy-reverso
        bindaddress = "0.0.0.0:8443";
        ldapbindaddress = "0.0.0.0:636";
        tls_chain = "/var/lib/acme/iam.wcbrpar.com/fullchain.pem";
        tls_key = "/var/lib/acme/iam.wcbrpar.com/privatekey.pem";
      };
    };
    
    unix = {
      settings = {
        hsm_type = "soft";
        default_shell = "/bin/zsh";
        home_attr = "uuid";
        home_prefix = "/home/";
        kanidm.pam_allowed_login_groups = [ "users" "admins" ];
        enablePam = lib.mkIf (hostName == "galactica") true;
      };
    };

    provision = lib.mkIf (hostName == "galactica") {
      enable = true;
      autoRemove = true;
      groups = {
        "admins" = { };
        "users" = { };
        "admin-tools" = { }; # Grupo para controle de acesso
      };
      persons = {
        "wjjunyor" = {
          displayName = "WQJ";
          legalName = "Walter Queiroz Jr";
          mailAddresses = [ "walter@wcbrpar.com" "walter@redcom.digital" "walter@walcor.com.br" ];
          groups = [ "admins" "users" "admin-tools" ];
        };
      };
      
    };
  };
  
  users.users.kanidm = {
    isSystemUser = true;
    extraGroups = [ "traefik" "acme" "nginx" "snm" ];
    group = "kanidm";
  };
  users.groups.kanidm = { };
  users.groups.traefik = { };

  # Garantir diretórios necessários
  systemd = {
    # Garantir diretórios necessários
    tmpfiles.rules = lib.mkIf (hostName == "galactica") [
      "d /var/lib/kanidm 0750 kanidm kanidm -"
      # Garante que o usuário kanidm possa ler os certificados do grupo traefik
      "z /var/lib/acme/*/fullchain.pem 0644 traefik traefik -"
      "z /var/lib/acme/*/privatekey.pem 0640 traefik traefik -"
    ];
    services."kanidm.service".requires = [ "traefik-certs-dumper.service" ];
  };
}

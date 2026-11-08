{ config, lib, pkgs, hostName, ... }:

let
  identityIds = import ../../users/identity-ids.nix;
  posixProvision = pkgs.writeText "kanidm-posix-provision.json" (
    builtins.toJSON {
      groups = {
        admins = {
          enableUnix = true;
          gidNumber = identityIds.groups.admins;
        };
        "unix-users" = {
          enableUnix = true;
          gidNumber = identityIds.groups.unixUsers;
        };
      };
      persons = builtins.mapAttrs (_: person: {
        enableUnix = true;
        gidNumber = person.gidNumber;
      }) identityIds.persons;
    }
  );

  mailSenderConfigScript = pkgs.writeShellScript "kanidm-mail-sender-config" ''
    set -euo pipefail

    ${pkgs.coreutils}/bin/install -d -o root -g kanidm -m 0750 /etc/kanidm

    token="$(${pkgs.coreutils}/bin/cat ${config.age.secrets.kanidm-mail-sender-token.path})"
    tokenToml="$(printf '%s' "$token" | ${pkgs.jq}/bin/jq -Rs .)"

    {
      printf 'token = %s\n' "$tokenToml"
      printf '%s\n' \
        'instance_display_name = "WCBRpar IAM"' \
        'instance_url = "https://iam.wcbrpar.com"' \
        'mail_from_address = "no-reply@wcbrpar.com"' \
        'mail_reply_to_address = "dev-ops@wcbrpar.com"' \
        'mail_relay = "mail.wcbrpar.com"' \
        'mail_username = "mail-sender@wcbrpar.com"' \
        'mail_password = ""' 
    } > /etc/kanidm/mail-sender.toml

    ${pkgs.coreutils}/bin/chown root:kanidm /etc/kanidm/mail-sender.toml
    ${pkgs.coreutils}/bin/chmod 0640 /etc/kanidm/mail-sender.toml
  '';

in

{
  
  age.secrets = {
    # Configurar um password para a conta idm_admin do Traefik
    kanidm-idm-admin-password = {
      file = ../../secrets/kanidmIdmAdminPassword.age;
      mode = "600";
      owner = "kanidm";
      group = "kanidm";
    };

    # Token oken do mail-sender
    kanidm-mail-sender-token = {
      file = ../../secrets/kanidmMailSenderToken.age;
      mode = "600";
      owner = "kanidm";
      group = "kanidm";
    };
 
  };

  networking.firewall = lib.mkIf (hostName == "galactica") {
    enable = true;
    allowedTCPPorts = [ 80 443 636 8443 ];
    extraCommands = ''
      # Remove qualq/uer regra DROP existente na porta 8443 (ignora se não existir)
      # iptables -D INPUT -p tcp --dport 8443 -j DROP 2>/dev/null || true
      # Garante acesso irrestrito à porta 8443 (já incluída no allowedTCPPorts, mas por segurança)
      # iptables -A INPUT -p tcp --dport 8443 -j ACCEPT
    '';
  };

  environment.systemPackages = with pkgs; [ kanidm_1_10 nginx ];
  
  # Declara o ldaps.<fqdn> para o host galactica! 
  networking = { 
    hosts = {
      "192.168.13.10" = [ "ldap.wcbrpar.com" "ldap.redcom.digital" "ldap.walcor.com.br" "ldap.wqueiroz.adv.br" ];
    };
  };

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
          rule = "Host(`iam.wcbrpar.com`) || Host(`iam.redcom.digital`) || Host(`iam.walcor.com.br`) || Host(`iam.wqueiroz.adv.br`)";
          service = "kanidm-service";
          entrypoints = ["websecure"];
          tls = {
            certResolver = "cloudflare";
            domains = [
              {
                main = "iam.wcbrpar.com";
                sans = [ 
                  "ldap.wcbrpar.com" 
                  "iam.redcom.digital" "ldap.redcom.digital"
                  "iam.walcor.com.br" "ldap.walcor.com.br"
                  "iam.wqueiroz.adv.br" "ldap.wqueiroz.adv.br"
                ];
              }
            ];
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

    # tcp = {
    #   middlewares = {
    #     "intranet" = {
    #       ipAllowList = {
    #         sourceRange = [
    #           "127.0.0.1/32"
    #           "192.168.13.0/24"
    #         ];
    #       };
    #     };
    #   };
    #
    #   routers = {
    #     LD-WPR = {
    #       rule = "HostSNI(`ldap.wcbrpar.com`) || HostSNI(`ldap.redcom.digital`) || HostSNI(`ldap.walcor.com.br`) || HostSNI(`ldap.wqueiroz.adv.br`)";
    #       service = "ldap-service";
    #       entrypoints = ["ldaps"];
    #       middlewares = [ "intranet" ];
    #       tls = {
    #         passthrough = true;
    #
    #       #   certResolver = "cloudflare";
    #       #   domains = [
    #       #     {
    #       #       main = "iam.wcbrpar.com";
    #       #       sans = [ 
    #       #         "ldap.wcbrpar.com" 
    #       #         "iam.redcom.digital" "ldap.redcom.digital"
    #       #         "iam.walcor.com.br" "ldap.walcor.com.br"
    #       #         "iam.wqueiroz.adv.br" "ldap.wqueiroz.adv.br"
    #       #       ];
    #       #     }
    #       #   ];
    #       };
    #     };
    #   };   
    #
    #   services = {
    #     ldap-service = {
    #       loadBalancer = {
    #         servers = [{ url = "galactica.wcbrpar.com:636"; }];
    #         passHostHeader = true;
    #       };
    #     };
    #   };
    # };
  };
  
  
  services.kanidm = {
    # package = pkgs.kanidm_1_10;
    package = pkgs.kanidmWithSecretProvisioning_1_10;
    
    client = {
      enable = true;
      settings = {
        uri = "https://iam.wcbrpar.com:8443";
        verify_ca = true;
        verify_hostnames = true;
      };
    };

    unix = {
      enable = true;
      settings = {
        hsm_type = "soft";
        default_shell = "/bin/zsh";
        home_attr = "uuid";
        home_prefix = "/home/";
        kanidm.pam_allowed_login_groups = [ "unix-users" "admins" ];
        enablePam = true;
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
        tls_chain = "/var/lib/acme/wcbrpar.com/fullchain.pem";
        tls_key = "/var/lib/acme/wcbrpar.com/privatekey.pem";
      };
    };
    
    provision = lib.mkIf (hostName == "galactica") {
      enable = true;
      autoRemove = true;
      idmAdminPasswordFile = config.age.secrets.kanidm-idm-admin-password.path;
      # O submódulo NixOS não tipa os atributos POSIX; o JSON é mesclado ao estado normal.
      extraJsonFile = posixProvision;
      groups = {
        "admins" = { };
        "users" = { };
        "unix-users" = { };
        "admin-tools" = { }; # Grupo para controle de acesso
      };
      persons = {
        "wjjunyor" = {
          displayName = "WQJ";
          legalName = "Walter Queiroz Jr";
          mailAddresses = [ "walter@wcbrpar.com" "walter@redcom.digital" "walter@walcor.com.br" ];
          groups = [ "admins" "users" "unix-users" "admin-tools" ];
          

        };
        "caroles" = {
          displayName = "CMQ";
          legalName = "Carolina Queiroz";
          mailAddresses = [ "carolina@wcbrpar.com" "carolina@redcom.digital" "carolina@walcor.com.br" ];
          groups = [ "admins" "users" "unix-users" "admin-tools" ];
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
    services = {
      kanidm = {
        serviceConfig = {
          # Isso fura o isolamento do Systemd e traz os arquivos para onde o Kanidm pode ver
          BindReadOnlyPaths = [
            "/var/lib/acme/iam.wcbrpar.com/fullchain.pem"
            "/var/lib/acme/iam.wcbrpar.com/privatekey.pem"
          ];
          # Garante que o serviço tenha permissão de leitura mesmo com hardening
          CapabilityBoundingSet = [ "~CAP_SYS_PTRACE" ]; 
          ReadOnlyPaths = [ "/var/lib/acme/iam.wcbrpar.com" ];
        };
      };
      kanidm-mail-sender = {
        description = "Kanidm Mail Sender";
        after = [ "network.target" "kanidm.service" ];
        wantedBy = [ "multi-user.target" ];
        
        serviceConfig = {
          ExecStartPre = [ "+${mailSenderConfigScript}" ];
          ExecStart = "${pkgs.kanidm_1_10}/bin/kanidm-mail-sender --client-config /etc/kanidm/config --mail-sender-config /etc/kanidm/mail-sender.toml";
          User = "kanidm";
          Group = "kanidm";
          Restart = "on-failure";
        };
      };
    };

    # Garantir diretórios necessários
    tmpfiles.rules = lib.mkIf (hostName == "galactica") [
      "d /var/lib/kanidm 0750 kanidm kanidm -"
    ];
    services."kanidm.service".after = [ "traefik.service" "traefik-certs-dumper.service" "systemd-tmpfiles-resetup.service"];
    services."kanidm.service".requires = [ "traefik-certs-dumper.service" ];
  };

}

{ config, lib, pkgs, hostName, ... }: 

let 

  # Importa as configurações de todos os hosts
  allHosts = import ../hosts/default.nix;

in

{

  services = {

    # Gerar os certificados pelo Traefik! 
    traefik = lib.mkIf (hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            MS-WPR = {
              # rule = "Host(`mail.wcbrpar.com`) || Host(`mail.redcom.digital`) || Host(`mail.walcor.com.br`) || Host(`mail.wqueiroz.adv.br`) || Host(`wcbrpar.com`) ";
              rule = "Host(`mail.wcbrpar.com`)";
              service = "noop@internal"; 
              entrypoints = ["websecure"];
              tls = {
                certResolver = "cloudflare";
                domains = [
                  { 
                    main = "mail.wcbrpar.com";
                  }
                ];
              };
            };
          };
        # Serviço dummy que não faz nada
        services.noop-service.loadBalancer.servers = [ { url = "http://localhost"; } ];
        };
      };
    };
    
    # Opção não disponível em services.mailserver
    postfix.settings.main = lib.mkIf (hostName == "galactica") {
      mynetworks = [
        # Endereços que sudo postconf -h mynetworks mostrou na Galactica
        "127.0.0.1/32"
        "37.205.8.86/32"
        "192.168.13.10/32"
        "[::1]/128"
        "[2a03:3b40:fe:410::1]/128"
        "[fe80::d873:e9ff:fe79:dff2]/128"
        "[fe80::73:a0ff:fe6c:1869]/128"

        # Pegasus e Yashuman: endereços ZeroTier específicos
        "192.168.13.20/32"
        "192.168.13.130/32"
      ];
    };
  };

  mailserver = lib.mkIf ( hostName == "galactica" ) {
    enable = true;
    enableNixpkgsReleaseCheck = true;
    fqdn = "mail.wcbrpar.com";
    sendingFqdn = "wcbrpar.com";
    domains = [ "wcbrpar.com" "redcom.digital" "walcor.com.br" "wqueiroz.adv.br" ];

    systemContact = "dev-ops@wcbrpar.com";
    systemDomain = "wcbrpar.com";
    systemName = "WCBRpar";


    # Certificados SSL via ACME (Gerenciados pelo Traefik e exportados pelo Dumper)
    x509 = { 
      # certificateFile = "/var/lib/acme/wcbrpar.com/fullchain.pem";
      # privateKeyFile = "/var/lib/acme/wcbrpar.com/privatekey.pem";
      certificateFile = "/var/lib/acme/${config.mailserver.fqdn}/fullchain.pem";
      privateKeyFile = "/var/lib/acme/${config.mailserver.fqdn}/privatekey.pem";
    };
    
    # Contas declarativas
    accounts = {
      "walter@wcbrpar.com" = {
        hashedPasswordFile = config.age.secrets.mail-walter-password.path;
        aliases = [ "postmaster@wcbrpar.com" "admin@wcbrpar.com" "abuse@wcbrpar.com" "dev-ops@wcbrpar.com" ];
        catchAll = [ "wcbrpar.com" "redcom.digital" "walcor.com.br" "wqueiroz.adv.br" ]; 
      };
    };

    # Integração LDAP (Dovecot + Postfix) — formato Kanidm
    ldap = {
      enable = true;
      uris = [ "ldaps://ldap.wcbrpar.com" "ldaps://ldap.redcom.digital" "ldaps://ldap.walcor.com.br" "ldaps://ldap.wqueiroz.adv.br" ];
      bind = { 
        # dn = "spn=mail_bind@wcbrpar.com";
        dn = "dn=token";
        passwordFile = config.age.secrets.ldap-mail-password.path;
      };
      searchBase = "dc=wcbrpar,dc=com";
      
      attributes = {
        password = null;
      };

      dovecot = {
        userFilter = "(&(objectClass=account)(mail=%u))";
        passFilter = "(&(objectClass=account)(mail=%u))";
      };
      postfix = {
        filter = "(&(objectClass=account)(mail=%s))";
      };
    };

    # Anti-spam via rspamd (integrado ao SNM)
    fullTextSearch = {
      enable = true;
      fallback = true;
    };

    # Hierarquia de pastas IMAP
    hierarchySeparator = "/"; 

    # TLS Reporting
    tlsrpt.enable = true;

    dmarcReporting = {
      enable = true;
    };
    
    # DKIM — SNM gera automaticamente em /var/dkim/
    dkim = { 
      enable = true;
      keyDirectory = "/var/lib/dovecot/dkim";
      defaults = {
        keyLength = 2048;
      };
      domains = {
        "wcbrpar.com".selectors = {
          # "${config.mailserver.dkim.defaults.selector}" = { };
          "rsa-202605" = {
            keyType = "rsa";
            keyLength = 2048;
          };
        };
        "redcom.digital".selectors.mail = {};
        "walcor.com.br".selectors.mail = {};
        "wqueiroz.adv.br".selectors.mail = {};
      };
    };

    # Versão do estado
    stateVersion = 22;

    # Configurações de armazenamento
    mailDirectory = "/var/mail/vhosts";

    # Configuração do Dovecot
    mailboxes = {
      Drafts = {
        auto = "subscribe";
        special_use = "\\Drafts";
      };
      Junk = {
        auto = "subscribe";
        fts_autoindex = false;
        special_use = "\\Junk";
      };
      Sent = {
        auto = "subscribe";
        special_use = "\\Sent";
      };
      Trash = {
        auto = "no";
        fts_autoindex = false;
        special_use = "\\Trash";
      };
      Archive = {
        auto = "subscribe";
        special_use = "\\Archive";
        fts_autoindex = true;
      };
    };

    # monitoring = {
    #   enable = true;
    #   alertAddress = "dev-ops@wcbrpar.com";
    # };

  };

  # Permissões: Dovecot e Postfix precisam ler os certificados em /var/lib/acme
  users = lib.mkIf ( hostName == "galactica" ) { 
    groups = {
      dovecot = {};
      snm = {};
    };
    users = {
      dovecot = {
        isSystemUser = true;
        group = "dovecot";
        extraGroups = [ "traefik" "acme" "snm" ];
      };
      postfix.extraGroups = [ "traefik" "acme" "snm" ];
    };
  };

  networking = {
   # Declara o mail.<fqdn> para o host galactica! 
    hosts = { # impmlementar variável ip // base role no host - 
      "192.168.13.10" = [ "mail.wcbrpar.com" "mail.redcom.digital" "mail.walcor.com.br" "mail.wqueiroz.adv.br" ];
    };

    # Firewall: portas de email
    firewall.allowedTCPPorts = lib.mkIf ( hostName == "galactica" ) [ 
      25    # SMTP
      465   # SMTPS
      587   # Submission
      993   # IMAPS
      4190  # ManageSieve
    ];
  };

  # Segredos para o Mailserver
  age.secrets = lib.mkIf ( hostName == "galactica" ) {
    ldap-mail-password = {
      file = ../../secrets/ldapMailPassword.age;
      owner = "root";
      group = "snm";
      mode = "440";
    };
    mail-walter-password = {
      file = ../../secrets/mailWalterPassword.age;
      owner = "root";
      group = "root";
      mode = "440";
    };
  };
}

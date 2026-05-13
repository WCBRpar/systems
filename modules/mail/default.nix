{ config, lib, pkgs, hostName, ... }: 

{

  services = {

    # Gerar os certificados pelo Traefik! 
    traefik = lib.mkIf (hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            MS-WPR = {
              rule = "Host(`mail.wcbrpar.com`) || Host(`mail.redcom.digital`) || Host(`mail.walcor.com.br`) || Host(`mail.wqueiroz.adv.br`) || Host(`wcbrpar.com`) ";
              service = "noop@internal"; 
              entrypoints = ["websecure"];
              tls = {
                certResolver = "cloudflare";
              };
            };
          };
        # Serviço dummy que não faz nada
        # services.noop-service.loadBalancer.servers = [ { url = "http://localhost"; } ];
        };
      };
    };
  };

  mailserver = lib.mkIf ( hostName == "galactica" ) {
    enable = true;
    fqdn = "wcbrpar.com";
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
      uris = [ "ldaps://iam.wcbrpar.com" ];
      bind = { 
        dn = "spn=mail_bind@wcbrpar.com";
        passwordFile = config.age.secrets.ldap-mail-password.path;
      };
      searchBase = "dc=wcbrpar,dc=com";
      
      attributes = {
        password = "mail";
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
    };

    monitoring = {
      enable = true;
      alertAddress = "dev-ops@wcbrpar.com";
    };

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

  # Firewall: portas de email
  networking.firewall.allowedTCPPorts = lib.mkIf ( hostName == "galactica" ) [ 
    25    # SMTP
    465   # SMTPS
    587   # Submission
    993   # IMAPS
    4190  # ManageSieve
  ];

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

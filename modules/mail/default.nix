{ config, lib, pkgs, hostName, ... }: 

{

  imports = [
    # SNM agora é importado via flake.nix (nixos-mailserver.nixosModules.mailserver)
    ./agenda.nix
  ];

  services = {

    # Gerar os certificados pelo Traefik! 
    traefik = lib.mkIf (hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            MS-ALL = {
              rule = "Host(`mail.wcbrpar.com`) || Host(`mail.redcom.digital`) || Host(`mail.walcor.com.br`) || Host(`mail.wqueiroz.adv.br`)";
              service = "noop-service"; 
              entrypoints = ["websecure"];
              tls = {
                certResolver = "cloudflare";
              };
            };
          };
        # Serviço dummy que não faz nada
        services.noop-service.loadBalancer.servers = [ { url = "http://localhost"; } ];
        };
      };
    };
  };

  mailserver = lib.mkIf ( hostName == "galactica" ) {
    enable = true;
    fqdn = "mail.wcbrpar.com";
    domains = [ "wcbrpar.com" "redcom.digital" "walcor.com.br" "wqueiroz.adv.br" ];

    # Certificados SSL via ACME (Gerenciados pelo Traefik e exportados pelo Dumper)
    x509 = { 
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
      uris = [ "ldaps://ldap.wcbrpar.com" ];
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

    # DKIM — SNM gera automaticamente em /var/dkim/
    dkimSigning = true;
    dkimKeyDirectory = "/var/dkim";

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

  };

  # Permissões: Dovecot e Postfix precisam ler os certificados em /var/lib/acme
  users.groups.dovecot = {};
  users.groups.snm = {};
  users.users.dovecot = {
    isSystemUser = true;
    group = "dovecot";
    extraGroups = [ "traefik" "acme" "snm" ];
  };
  users.users.postfix.extraGroups = [ "traefik" "acme" "snm" ];

  # Pre-start para evitar falha do Dovecot se o dumper ainda não exportou os arquivos
  systemd.services.dovecot.preStart = lib.mkBefore ''
    mkdir -p /var/lib/acme/mail.wcbrpar.com
    if [ ! -f /var/lib/acme/mail.wcbrpar.com/fullchain.pem ]; then
      touch /var/lib/acme/mail.wcbrpar.com/fullchain.pem
      touch /var/lib/acme/mail.wcbrpar.com/privatekey.pem
      chown -R traefik:traefik /var/lib/acme/mail.wcbrpar.com
      chmod -R 750 /var/lib/acme/mail.wcbrpar.com
    fi
  '';

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

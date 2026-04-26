{ config, lib, pkgs, hostName, ... }: 

{

  imports = [
    # SNM agora é importado via flake.nix (nixos-mailserver.nixosModules.mailserver)
    # Não mais necessário o fetchTarball

    # calDAV e AntiSpam
    ./agenda.nix
    # ./antispam.nix  # rspamd do SNM substitui
  ];

  mailserver = lib.mkIf ( hostName == "galactica" ) {
    enable = true;
    fqdn = "mail.wcbrpar.com";
    domains = [ "wcbrpar.com" "redcom.digital" "walcor.com.br" "wqueiroz.adv.br" ];

    # Certificados SSL via ACME com DNS challenge Cloudflare
    # O SNM gerencia seus próprios certificados via security.acme
    x509 = { 
      # certificateScheme = "acme";
      # acmeCertificateDomains = "mail.wcbrpar.com";
      useACMEHost = config.mailserver.fqdn;
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
    # Kanidm expõe LDAP read-only. O bind DN usa o formato spn=<account>@<domain>
    # A searchBase no Kanidm é dc=<domain components>
    ldap = {
      enable = true;
      uris = [ "ldaps://ldap.wcbrpar.com" ];
      bind = { 
        dn = "spn=mail_bind@wcbrpar.com";
        passwordFile = config.age.secrets.ldap-mail-password.path;
      };
      searchBase = "dc=wcbrpar,dc=com";
      dovecot = {
        # Kanidm usa objectClass=account e atributo 'mail' para email
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
      # enforced = "body";
    };

    # Hierarquia de pastas IMAP
    hierarchySeparator = "/"; 

    # DKIM — SNM gera automaticamente em /var/dkim/
    dkimSigning = true;
    dkimKeyDirectory = "/var/dkim";

    # Versão do estado
    stateVersion = 1;

    # Configurações de armazenamento
    # SNM 2.x usa mailDirectory para o caminho base
    mailDirectory = "/var/mail/vhosts";

    # Configuração do Dovecot via localConfiguration (SNM 2.x)
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

    # Migração 2: Habilitar UUID para home directories no LDAP
    # Necessário para compatibilidade com Dovecot 2.3+
    # Adiciona atributos necessários para lookup de UID/GID via LDAP
    ldap.dovecot.passAttrs = "uid gid home uidNumber gidNumber";

    # Script de migração será executado automaticamente pelo SNM
    # Para mais detalhes: https://nixos-mailserver.readthedocs.io/en/latest/migrations.html

  };

  # Certificado ACME para mail.wcbrpar.com via DNS challenge Cloudflare
  security.acme.certs."mail.wcbrpar.com" = lib.mkIf ( hostName == "galactica" ) {
    dnsProvider = "cloudflare";
    dnsResolver = "1.1.1.1:53";
    environmentFile = config.age.secrets.cloudflare-api-key.path;
    # Postfix e Dovecot precisam ler os certificados
    group = "mail";
    reloadServices = [ "postfix" "dovecot2" ];
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
      group = "root";
      mode = "400";
    };
    mail-walter-password = {
      file = ../../secrets/mailWalterPassword.age;
      owner = "root";
      group = "root";
      mode = "400";
    };
  };
}

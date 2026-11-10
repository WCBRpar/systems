{
  config,
  lib,
  pkgs,
  hostName, 
  ...
}: {
  environment.systemPackages = [
    # pkgs.onlyoffice-workspace.communityServer
    # pkgs.onlyoffice-workspace.documentServer
  ];

  # Segredos para o NextCloud e para o OnlyOffice
  # Ajustes de permissões para acesso aos segredos!
  users = {
    groups = {
      nextcloud = {};
      office = {};
    };
    users = {
      nextcloud = { isSystemUser = true; group = "nextcloud"; extraGroups = [ "office" ]; };
      nginx = { isSystemUser = true; group = "nginx"; extraGroups = [ "office" ]; };
      kanidm = { isSystemUser = true; group = "kanidm"; extraGroups = [ "office" ]; };
    };
  };
  age.secrets = {
    nextcloud-admin-password = {
      file = ../../secrets/nextcloudAdminPassword.age;
      # Se for o Galactica, o dono é o Kanidm. Se for o Pegasus, o dono é o Nextcloud.
      owner = if hostName == "galactica" then "kanidm" else "nextcloud";
      group = "office";
      mode = "440";
    };
    nextcloud-oauth-secret = {
      file = ../../secrets/nextcloudOauthSecret.age;
      owner = "kanidm";
      group = "office";
      mode = "440";
    };
    onlyoffice-jwt-secret = {
      file = ../../secrets/onlyofficeJwtSecret.age;
      owner = "root";
      group = "office";
      mode = "440";
    };
    onlyoffice-security-nonce = {
      file = ../../secrets/onlyofficeSecurityNonce.age;
      owner = "root";
      group = "office";
      mode = "440";
    };

  };

  systemd = lib.mkIf (hostName == "pegasus") {
    services.nextcloud-setup ={
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
      unitConfig.JoinsNamespaceOf = "postgresql.service"; 
    };
    tmpfiles.rules = [
      # d: diretório, modo 0750, usuário nextcloud, grupo nextcloud
      # Z: aplica recursivamente o dono e permissões (importante para o diretório config)
      "d /var/lib/nextcloud 0750 nextcloud nextcloud -"
      "Z /var/lib/nextcloud 0750 nextcloud nextcloud -"
      "d /var/lib/nextcloud/config 0750 nextcloud nextcloud -"
    ];
  };

  services = {

    # Configuração OAuth2 do Kanidm para o NextCloud
    kanidm = lib.mkIf (hostName == "galactica") {
      provision.systems.oauth2 = {
        "nextcloud" = {
          displayName = "NextCloud Office";
          originUrl = [
            "https://cloud.wcbrpar.com/apps/oidc_login/oidc"
          ];
          originLanding = "https://cloud.wcbrpar.com";
          imageFile = ../../media-assets/iam-auth-badges/nextcloud-auth.svg;
          public = false;
          enableLegacyCrypto = true;
          preferShortUsername = true;
          claimMaps = {
            is_admin = {
              valuesByGroup = {
                "admin-tools" = [ "1" ];
              };
            };
          };
          scopeMaps = {
            "users" = [  "openid" "profile" "email" "groups_name" ];
            "admins" = [ "openid" "profile" "email" "groups_name" ];
            "admin-tools" = [ "openid" "profile" "email" "groups_name" ];
          };
          basicSecretFile = config.age.secrets.nextcloud-oauth-secret.path;
        };
      };
    };

    # Configura os privilégios do NexCloud para a DB personalizada. 
    postgresql = lib.mkIf (hostName == "pegasus") {
      enable = true;
      ensureDatabases = [ "ncdb-wcbrpar" "nextcloud" ];
      ensureUsers = [ { name = "nextcloud"; ensureDBOwnership = true; } ];
    };
    
    nextcloud = lib.mkIf ( hostName == "pegasus" ) {

      enable = true;
      hostName = "cloud.wcbrpar.com";

      # Need to manually increment with every major upgrade.
      package = pkgs.nextcloud35;

      # Amplia o buffer de strings internadas do OPcache para 16 MiB.
      phpOptions."opcache.interned_strings_buffer" = "16";

      # Let NixOS install and configure the database automatically.
      database.createLocally = true;

      # Let NixOS install and configure Redis caching automatically.
      configureRedis = true;

      # Increase the maximum file upload size to avoid problems uploading videos.
      maxUploadSize = "25G";
      
      https = false;
      
      autoUpdateApps.enable = true;
      extraAppsEnable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        # List of apps we want to install and are already packaged in
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
        inherit calendar contacts mail memories notes oidc_login onlyoffice recognize tasks ; # +external --collectives +socialsharing_whatsapp 
 
      };
      # Habilita a instalação de aplicativos via appstore - mesmo havendo extra-apps definidos
      appstoreEnable = true;

      # Injeta o segredo em config.php sem gravá-lo no Nix store.
      secrets.oidc_login_client_secret = config.age.secrets.nextcloud-oauth-secret.path;

      settings = {

        loglevel = 2;
        log_type = "systemd";
        logtimezone = "America/Campo_Grande";
        
        # Horário UTC: 06:00 UTC = 02:00 em Campo Grande.
        default_timezone = "America/Campo_Grande";
        maintenance_window_start = 6;
        # Identificador estável desta instância única de Nextcloud.
        serverid = 1;

        config_is_read_only = false;
        default_phone_region = "BR";
        default_language = "pt_BR";
        default_locale = "pt_BR";

        overwriteprotocol = "https";
        # Mantém o callback OIDC no domínio registrado no cliente Kanidm,
        # mesmo quando o usuário acessa por um domínio alternativo.
        overwritehost = "cloud.wcbrpar.com";

        trusted_proxies = [ "127.0.0.1" "::1" "192.168.13.10" ];
        trusted_domains = [ "cloud.wcbrpar.com" "cloud.redcom.digital" "cloud.walcor.com.br" "cloud.wqueiroz.adv.br" ];
        
        # Permite conexões locais ao servidor IDP caso estejam na mesma rede
        allow_local_remote_servers = true;
        
        # Desativa ou mantém múltiplos backends de login false = APENAS o Kanidm
        allow_multiple_user_backends = false;

        # Garante que o painel de perfis esteja ativado na raiz do sistema
        "profile.enabled" = true;

        # Altera declarativamente as regras de controle do gerenciador de contas do Nextcloud.
        # Ao definir o escopo como "local", o Nextcloud libera a edição desses dados na interface
        # pessoal do proprietário, tratando o próprio banco local como autoridade de escrita.
        "account_manager.default_property_scope" = {
          "displayname" = "local";
          "email" = "local";
          "phone" = "local";
          "avatar" = "local";
        };

        # Configuração declarativa de mapeamento para as pastas especiais IMAP
        "app.mail.accounts.default" = {
          sentFolder = "Sent";       # Modifique para "Enviados" se o servidor exigir em português
          trashFolder = "Trash";     # Modifique para "Lixeira" ou "Trash" se necessário
          draftsFolder = "Drafts";   # Modifique para "Rascunhos" ou "Drafts" se necessário
        };        

        # Habilita o arquivamento global e define o nome padrão da pasta (ex: "Archive" ou "Arquivo")
        "app.mail.archive.folder" = "Archive";

        #Configutação Padrões SMTP/IMAP
        # mail_smtphost = "mail.wcbrpar.com";
        # mail_smtpmode = "smtp";
        # mail_smtpsecure = "ssl";

        # Configurações OIDC
        oidc_login_client_id = "nextcloud";
        oidc_login_provider_url = "https://iam.wcbrpar.com/oauth2/openid/nextcloud";
        oidc_login_end_session_redirect = false;
        oidc_login_logout_url = "https://iam.wcbrpar.com/ui/logout";

        # Mapeamentos e Comportamento
        oidc_login_attributes = {
          id = "preferred_username";
          mail = "email";
          name = "name";
          groups = "groups";
          is_admin = "is_admin";
        };

        oidc_login_auto_redirect = true; 
        oidc_login_redir_fallback = false;
        oidc_login_tls_verify = true;
        # Auto-criação de usuários e login automático (opcional )
        oidc_login_disable_registration = false;

        # Refinamento OIDC
        oidc_login_button_text = "Logar com Kanidm";
        oidc_login_hide_password_form = true; 
        oidc_login_code_challenge_method = "S256";
        oidc_login_use_id_token = true;
        oidc_login_scope = "openid profile email groups_name";
        # oidc_login_admin_group = "admin-tools"; 
        
        # Proxy e Segurança
        "allow_user_to_change_display_name" = false;
        "lost_password_link" = "disabled";
        
      };

      config = {
        #  defaultTimezone = "America/Campo_Grande";
        dbtype = "pgsql";
        # dbname = "ncdb-wcbrpar";
        dbuser = "nextcloud";
        # dbpassFile = config.age.secrets.nextcloud-admin-password.path;
        dbhost = "/run/postgresql";
      };

      # Notificações
      # notify_push = {
      #   enable = true;
      #   package = pkgs.nextcloud-notify_push;
      # };

      # Demais opções
      imaginary.enable = true;
      enableImagemagick = true;

    };

     # nginx = lib.mkIf (hostName == "pegasus") {
     #  virtualHosts."cloud.wcbrpar.com".serverAliases = [
     #    "cloud.redcom.digital"
     #    "cloud.walcor.com.br"
     #    "cloud.wqueiroz.adv.br"
     #  ];
     # };


    onlyoffice = lib.mkIf ( hostName == "pegasus" ) {

      enable = true;
      hostname = "office.wcbrpar.com";
      jwtSecretFile = config.age.secrets.onlyoffice-jwt-secret.path;
      securityNonceFile = config.age.secrets.onlyoffice-security-nonce.path;

    };

    traefik = lib.mkIf (config.networking.hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            NC-ALL = {
              rule = "Host(`cloud.wcbrpar.com`) || Host(`cloud.redcom.digital`) || Host(`cloud.walcor.com.br`) || Host(`cloud.wqueiroz.adv.br`)";
              service = "nextcloud-service";
              entrypoints = ["websecure"];
              tls = {
                certResolver = "cloudflare";
              };
              middlewares = [ "nextcloud-hsts" ];
              # middlewares = ["onlyoffice-prefix"];
            };
            OO-ALL = {
              rule = "Host(`office.wcbrpar.com`) || Host(`office.redcom.digital`) || Host(`office.walcor.com.br`) || Host(`office.wqueiroz.adv.br`)";
              service = "onlyoffice-service";
              entrypoints = ["websecure"];
              tls = {
                certResolver = "cloudflare";
              };
              middlewares = ["onlyoffice-prefix"];
            };
          };
          services = {
            nextcloud-service = {
              loadBalancer = {
                servers = [{url = "http://pegasus.wcbrpar.com";}];
                passHostHeader = true;
              };
            };
            onlyoffice-service = {
              loadBalancer = {
                servers = [{url = "http://pegasus.wcbrpar.com:8008";}];
                passHostHeader = true;
                healthCheck = {
                  path = "/healthcheck/";
                  interval = "10s";
                  timeout = "3s";
                };
              };
            };
          };
          middlewares = {
            nextcloud-hsts = {
              headers.stsSeconds = 15552000;
            };
            onlyoffice-prefix = {
              stripPrefix = {
                prefixes = ["/"];
                forceSlash = true;
              };
            };
          };
        };
      };
    };

    # onlyoffice.workspace = lib.mkIf (config.networking.hostName == "pegasus") {
    #   enable = true;
    #   domain = "office.wcbrpar.com";
    #   enableBackup = true; # Ativa backups automáticos do MySQL e PostgreSQL
    # };

    # nginx.virtualHosts."office.wcbrpar.com" = lib.mkIf (config.networking.hostName == "pegasus") {
    #   extraConfig = ''
    #     absolute_redirect off;
    #   '';
    # };
  };

  fonts.fontDir = lib.mkIf (config.networking.hostName == "pegasus") { 
    enable = true; 
  };
}


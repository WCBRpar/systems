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
      kanidm = { isSystemUser = true; group = "kanidm"; extraGroups = [ "office" ]; };
    };
  };
  age.secrets = {
    nextcloud-admin-password = {
      file = ../../secrets/nextcloudAdminPassword.age;
      owner = "root";
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
    # kanidm = lib.mkIf (hostName == "galactica") {
    #   provision.systems.oauth2 = {
    #     "nextcloud" = {
    #       displayName = "NextCloud Office";
    #       originUrl = [
    #         "https://cloud.wcbrpar.com/apps/oidc_login/oidc"
    #       ];
    #       originLanding = "https://cloud.wcbrpar.com";
    #       imageFile = ../../media-assets/iam-auth-badges/nextcloud-auth.svg;
    #       public = true;
    #       scopeMaps = {
    #         "users" = [  "openid" "profile" "email" "groups" ];
    #         "admins" = [ "openid" "profile" "email" "groups" ];
    #         "admin-tools" = [ "openid" "profile" "email" "groups" ];
    #       };
    #       basicSecretFile = config.age.secrets.nextcloud-oauth-secret.path;
    #     };
    #   };
    # };

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
      package = pkgs.nextcloud33;

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
        inherit calendar contacts mail notes onlyoffice tasks oidc oidc_login user_oidc;

      };

      settings = {

        loglevel = 0;

        config_is_read_only = false;
        default_phone_region = "BR";
        default_language = "pt_BR";
        default_locale = "pt_BR";

        overwriteprotocol = "https";

        trusted_proxies = [ "127.0.0.1" "::1" "192.168.13.10" ];
        trusted_domains = [ "cloud.redcom.digital" "cloud.walcor.com.br" "cloud.wqueiroz.adv.br" ];
        
        # Configurações OIDC
        oidc_login_client_id = "nextcloud";
        oidc_login_provider_url = "https://iam.wcbrpar.com/oauth2/openid/nextcloud";
        oidc_login_logout_url = "https://iam.wcbrpar.com/ui/logout";

        # Mapeamentos e Comportamento
        oidc_login_attributes = {
          id = "preferred_username";
          mail = "email";
          display_name = "name";
          groups = "groups";
        };
        # Auto-criação de usuários e login automático (opcional )
        oidc_login_auto_redirect = false; # Mantenha false para testar o botão primeiro
        oidc_login_redir_fallback = true;
        oidc_login_tls_verify = true;
        oidc_login_disable_registration = false;
        
        # Secrets! 
        secrets = {
          oidc_login_client_secret = config.age.secrets.nextcloud-oauth-secret.path;
        };
      };

      config = {
        dbtype = "pgsql";
        # dbname = "ncdb-wcbrpar";
        dbuser = "nextcloud";
        # dbpassFile = config.age.secrets.nextcloud-admin-password.path;
        dbhost = "/run/postgresql";
        adminuser = "admin";
        adminpassFile = config.age.secrets.nextcloud-admin-password.path;
      };
    };

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


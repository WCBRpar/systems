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
  age.secrets = lib.mkIf ( hostName == "pegasus" ) {
    nextcloud-admin-password = {
      file = ../../secrets/nextcloudAdminPassword.age;
      owner = "root";
      group = "nextcloud";
      mode = "440";
    };
    onlyoffice-jwt-secret = {
      file = ../../secrets/onlyofficeJwtSecret.age;
      owner = "root";
      group = "onlyoffice";
      mode = "440";
    };
    onlyoffice-security-nonce = {
      file = ../../secrets/onlyofficeSecurityNonce.age;
      owner = "root";
      group = "onlyoffice";
      mode = "440";
    };

  };

  systemd.services.nextcloud-setup = {
    requires = [ "postgresql.service" ];
    after = [ "postgresql.service" ];
  };

  services = {

    # Configura os privilégios do NexCloud para a DB personalizada. 
    postgresql = lib.mkIf (hostName == "pegasus") {
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
        inherit calendar contacts mail notes onlyoffice tasks;

      };

      settings = {

        loglevel = 0;

        config_is_read_only = false;
        default_phone_region = "BR";
        overwriteprotocol = "https";
        trusted_proxies = [ "127.0.0.1" "::1" "192.168.13.10" ];
        trusted_domains = [ "cloud.redcom.digital" "cloud.walcor.com.br" "cloud.wqueiroz.adv.br" ];

      };

      config = {
        dbtype = "pgsql";
        dbname = "ncdb-wcbrpar";
        dbuser = "nextcloud";
        # dbpassFile = config.age.secrets.nextcloud-admin-password.path;
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


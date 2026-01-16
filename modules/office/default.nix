{
  config,
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    pkgs.onlyoffice-workspace.communityServer
    pkgs.onlyoffice-workspace.documentServer
  ];

  services = {
    traefik = lib.mkIf (config.networking.hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            OO-ALL = {
              rule = "Host(`office.wcbrpar.com`) || Host(`office.redcom.digital`)";
              service = "onlyoffice-service";
              entrypoints = ["websecure"];
              tls = {
                certResolver = "cloudflare";
              };
              middlewares = ["onlyoffice-prefix"];
            };
          };
          services = {
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

    onlyoffice.workspace = lib.mkIf (config.networking.hostName == "pegasus") {
      enable = true;
      domain = "office.wcbrpar.com";
      enableBackup = true; # Ativa backups automáticos do MySQL e PostgreSQL
    };

    nginx.virtualHosts."office.wcbrpar.com" = lib.mkIf (config.networking.hostName == "pegasus") {
      extraConfig = ''
        absolute_redirect off;
      '';
    };
  };

  fonts.fontDir = lib.mkIf (config.networking.hostName == "pegasus") { 
    enable = true; 
  };
}


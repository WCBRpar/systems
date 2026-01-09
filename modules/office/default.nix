{
  config,
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [onlyoffice-documentserver];

  services = {
    traefik = lib.mkIf (config.networking.hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            OO-ALL = {
              # rule = "Host(`office.wcbrpar.com`)";
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

    onlyoffice = lib.mkIf (config.networking.hostName == "pegasus") {
      enable = true;
      port = 8008;
      hostname = "office.wcbrpar.com";
      enableExampleServer = true;
      examplePort = 8009;

      
      };

    nginx.virtualHosts."office.wcbrpar.com" = lib.mkIf (config.networking.hostName == "pegasus") {
      extraConfig = ''
        # Force nginx to return relative redirects. This lets the browser
        # figure out the full URL. This ends up working better because it's in
        # front of the reverse proxy and has the right protocol, hostname & port.
        absolute_redirect off;
      '';
    };
  };

  # Necessário para que o Only Office possa reconhecer as fontes instaladas
  fonts.fontDir = lib.mkIf (config.networking.hostName == "pegasus") { 
    enable = true; 
  };

}

{ config, lib, pkgs,  ... }:

{

  services = {
    
    n8n = lib.mkIf (config.networking.hostName == "pegasus") {
      enable = true;
      # Open the default port (5678) in the firewall
      openFirewall = true;
      environment = {
      };
    };

    traefik = lib.mkIf (config.networking.hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            N8-ALL = {
              # rule = "Host(`n8n.wcbrpar.com`) || Host(`n8n.redcom.digital`)";
              # service = "n8n-service";
              # entrypoints = ["websecure"];
              # tls.certResolver = "cloudflare";
            };
          };
          
          services = {
            n8n-service = {
              loadBalancer = {
                servers = [{ url = "http://pegasus.wcbrpar.com:5678"; }];
                passHostHeader = true;
              };
            };
          };
        };
      };
    };
  };
      
  networking.firewall = lib.mkIf ( config.networking.hostName == "pegasus" ) {
    allowedTCPPorts = [ 5678 ];
  };

}

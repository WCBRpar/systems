{ config, lib, ... }: {
  services = {
    traefik = lib.mkIf (config.networking.hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            # Odoo normal - páginas, API, etc.
            OD-ALL = {
              rule = "Host(`crm.wcbrpar.com`) || Host(`crm.redcom.digital`)";
              service = "odoo-service";
              entrypoints = ["websecure"];
              tls.certResolver = "cloudflare";
            };
            
            # Long polling - notificações em tempo real
            OD-LONGPOLLING = {
              rule = "(Host(`crm.wcbrpar.com`) || Host(`crm.redcom.digital`)) && PathPrefix(`/longpolling`)";
              service = "odoo-longpolling-service";
              entrypoints = ["websecure"];
              tls.certResolver = "cloudflare";
            };
          };
          
          services = {
            # Serviço principal do Odoo
            odoo-service.loadBalancer.servers = [{ url = "http://pegasus.wcbrpar.com:8011"; }];
            
            # Serviço de long polling
            odoo-longpolling-service.loadBalancer.servers = [{ url = "http://pegasus.wcbrpar.com:8072"; }];
          };
        };
      };
    };

    odoo = lib.mkIf (config.networking.hostName == "pegasus") {
      enable = true;
      domain = "crm.redcom.digital";
      settings = {
        http_port = 8011;
      };
    };
  };
}

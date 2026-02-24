{ config, lib, pkgs, ... }: 

{

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

            OD-ADF = {
              rule = "Host(`novo.adufms.org.br`)";
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
      domain = "redcom.digital";
      settings = {
        options = {
          http_port = 8011;
          db_host = "localhost";
          db_port = 5432;
          db_user = "odoo";
          # db_password = config.age.secrets.odoo-databasekey.path; 
          db_password = "odoo";

          # dbFilter = "^(wcbrpar\\.com|redcom\\.digital)$ -> WCBRpar|^(adufms\\.org\\.br)$ -> adufms";

        };
      };
      autoInit = true;
      addons = [
        # dbfilterHeaderAddon
        # pkgs.odoo_enterprise
        pkgs.python314Packages.click-odoo
        pkgs.python314Packages.click-odoo-contrib
        pkgs.python314Packages.hatch-odoo
        pkgs.python314Packages.manifestoo
        pkgs.python314Packages.manifestoo-core
        pkgs.python314Packages.whool
        pkgs.python314Packages.pylint-odoo        
        pkgs.python314Packages.setuptools-odoo

      ];
    };
  };
}

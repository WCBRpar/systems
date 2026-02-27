{ config, lib, pkgs, ... }:

let
  # Pacote que fornece o módulo dbfilter_from_header da OCA
  dbfilterHeaderAddon = pkgs.stdenv.mkDerivation {
    name = "odoo-addon-dbfilter_from_header";
    src = pkgs.fetchFromGitHub {
      owner = "OCA";
      repo = "server-tools";
      rev = "18.0";
      # Substitua pelo hash correto após o primeiro build
      sha256 = "sha256-x+JrjAkPCp62RYC6SkgTX/cZEg1bSGNJtmis82XoopU=";
    };
    installPhase = ''
      mkdir -p $out/dbfilter_from_header
      cp -r dbfilter_from_header/* $out/dbfilter_from_header/
    '';
  };
in

{
  services = {
    traefik = lib.mkIf (config.networking.hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            OD-ALL = {
              rule = "Host(`crm.wcbrpar.com`) || Host(`crm.redcom.digital`)";
              service = "odoo-service";
              entrypoints = ["websecure"];
              tls.certResolver = "cloudflare";
              middlewares = ["dbfilter-wcbrpar"];
            };
            OD-ADF = {
              rule = "Host(`novo.adufms.org.br`)";
              service = "odoo-service";
              entrypoints = ["websecure"];
              tls.certResolver = "cloudflare";
              middlewares = ["dbfilter-adufms"];
            };
            OD-LONGPOLLING = {
              rule = "(Host(`crm.wcbrpar.com`) || Host(`crm.redcom.digital`)) && PathPrefix(`/longpolling`)";
              service = "odoo-longpolling-service";
              entrypoints = ["websecure"];
              tls.certResolver = "cloudflare";
            };
          };
          middlewares = {
            dbfilter-wcbrpar = {
              headers = {
                customRequestHeaders = {
                  X-Odoo-dbfilter = "^WCBRpar$";
                };
              };
            };
            dbfilter-adufms = {
              headers = {
                customRequestHeaders = {
                  X-Odoo-dbfilter = "^adufms$";
                };
              };
            };
          };
          services = {
            odoo-service.loadBalancer.servers = [{ url = "http://pegasus.wcbrpar.com:8011"; }];
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
          db_password = "odoo";  # ⚠️ Temporário
          list_db = true;
          proxy_mode = true;
          dbfilter = ".*";
          server_wide_modules = "base,web,dbfilter_from_header";
        };
      };
      autoInit = true;
      addons = [
        dbfilterHeaderAddon          # Agora é um pacote válido
        # pkgs.odoo_enterprise (se necessário)
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

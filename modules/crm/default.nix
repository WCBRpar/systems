{ config, lib, pkgs, ... }:

let
  # Pacote que fornece o módulo dbfilter_from_header da OCA para Odoo 19
  dbfilterHeaderAddon = pkgs.stdenv.mkDerivation {
    name = "odoo-addon-dbfilter_from_header";
    src = pkgs.fetchFromGitHub {
      owner = "OCA";
      repo = "server-tools";
      rev = "18.0";  
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
          # Use age para a senha (comente a linha abaixo e descomente a segura)
          # db_password = config.age.secrets.odoo-databasekey.path;
          db_password = "odoo";          # ⚠️ Temporário
          list_db = true;                # Habilita gerenciador web (opcional)
          proxy_mode = true;             # Necessário para confiar nos cabeçalhos
          dbfilter = ".*";               # Filtro global permissivo
          server_wide_modules = "base, web, dbfilter_from_header";
          # Evita banco padrão "odoo" que causa erros de tabela inexistente
          db_name = false;
        };
      };
      autoInit = true;
      addons = [
        dbfilterHeaderAddon
        # pkgs.odoo_enterprise  # Descomente se necessário
      ];
    };
  };
}

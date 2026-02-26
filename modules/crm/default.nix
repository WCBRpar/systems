{ config, lib, pkgs, ... }:

let
  # Obtém o módulo dbfilter_from_header do repositório OCA/server-tools
  # ATENÇÃO: Substitua o sha256 pelo hash correto após o primeiro build.
  dbfilterHeaderAddon = pkgs.fetchFromGitHub {
    owner = "OCA";
    repo = "server-tools";
    rev = "18.0";  # Ou um commit específico, ex: "7c7a8f3..."
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Hash inicial (será corrigido)
  } + "/dbfilter_from_header";
in

{
  services = {
    traefik = lib.mkIf (config.networking.hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            # Roteador para os domínios que devem usar o banco WCBRpar
            OD-ALL = {
              rule = "Host(`crm.wcbrpar.com`) || Host(`crm.redcom.digital`)";
              service = "odoo-service";
              entrypoints = ["websecure"];
              tls.certResolver = "cloudflare";
              middlewares = ["dbfilter-wcbrpar"];   # Injeta cabeçalho para banco WCBRpar
            };

            # Roteador para o domínio que deve usar o banco adufms
            OD-ADF = {
              rule = "Host(`novo.adufms.org.br`)";
              service = "odoo-service";
              entrypoints = ["websecure"];
              tls.certResolver = "cloudflare";
              middlewares = ["dbfilter-adufms"];    # Injeta cabeçalho para banco adufms
            };

            # Long polling - não precisa de filtro de banco
            OD-LONGPOLLING = {
              rule = "(Host(`crm.wcbrpar.com`) || Host(`crm.redcom.digital`)) && PathPrefix(`/longpolling`)";
              service = "odoo-longpolling-service";
              entrypoints = ["websecure"];
              tls.certResolver = "cloudflare";
              # Sem middlewares
            };
          };

          # Middlewares para injetar o cabeçalho X-Odoo-dbfilter
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
          # Recomendação: use age para gerenciar a senha com segurança
          # db_password = config.age.secrets.odoo-databasekey.path;
          db_password = "odoo";  # ⚠️ Temporário – substitua pelo segredo assim que possível

          list_db = true;                # Habilita o gerenciador web (opcional)

          proxy_mode = true;              # Necessário para confiar nos cabeçalhos do proxy

          # Filtro global permissivo – a seleção real será feita pelo cabeçalho
          dbfilter = ".*";

          # Carrega o módulo dbfilter_from_header como server-wide
          server_wide_modules = "base,web,dbfilter_from_header";
        };
      };

      autoInit = true;

      # Lista de addons: inclui o dbfilter_from_header e os demais pacotes
      addons = [
        dbfilterHeaderAddon          # Módulo da OCA para filtro por cabeçalho
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

{ config, lib, pkgs, ... }:


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
        # pkgs.odoo_enterprise  # Descomente se necessário
        pkgs.odooAddons.dbfilter-from-header
        pkgs.odooAddons.sequence-python
        pkgs.odooAddons.bus-alt-connection
        pkgs.odooAddons.base-name-search-improved
        pkgs.odooAddons.base-fontawesome-web-editor
        pkgs.odooAddons.base-fontawesome
        pkgs.odooAddons.partner-statement
        pkgs.odooAddons.account-invoice-inter-company
        pkgs.odooAddons.mail-multicompany
        pkgs.odooAddons.purchase-sale-inter-company
        pkgs.odooAddons.res-company-active
        pkgs.odooAddons.account-multicompany-easy-creation
        pkgs.odooAddons.base-multi-company
        pkgs.odooAddons.calendar-event-multi-company
        pkgs.odooAddons.calendar-event-type-multi-company
        pkgs.odooAddons.crm-lost-reason-multi-company
        pkgs.odooAddons.crm-stage-multi-company
        pkgs.odooAddons.crm-tag-multi-company
        pkgs.odooAddons.hr-employee-multi-company
        pkgs.odooAddons.ir-filters-multi-company
        pkgs.odooAddons.ir-ui-view-multi-company
        pkgs.odooAddons.login-all-company
        pkgs.odooAddons.mail-template-multi-company
        pkgs.odooAddons.partner-category-multi-company
        pkgs.odooAddons.partner-multi-company
        pkgs.odooAddons.pos-category-multicompany
        pkgs.odooAddons.product-multi-company
        pkgs.odooAddons.product-multi-company-stock
        pkgs.odooAddons.product-tax-multicompany-default
        pkgs.odooAddons.purchase-sale-stock-inter-company
        pkgs.odooAddons.res-company-category
        pkgs.odooAddons.res-company-code
        pkgs.odooAddons.res-company-search-view
        pkgs.odooAddons.res-partner-industry-multi-company
        pkgs.odooAddons.utm-medium-multi-company
        pkgs.odooAddons.utm-source-multi-company
        pkgs.odooAddons.l10n-br-account-due-list
        pkgs.odooAddons.l10n-br-account-payment-order
        pkgs.odooAddons.l10n-br-base
        pkgs.odooAddons.l10n-br-base-l10n-br-compat
        pkgs.odooAddons.l10n-br-cnpj-search
        pkgs.odooAddons.l10n-br-coa
        pkgs.odooAddons.l10n-br-crm
        pkgs.odooAddons.l10n-br-crm-cnpj-search
        pkgs.odooAddons.l10n-br-cte-spec
        pkgs.odooAddons.l10n-br-currency-rate-update
        pkgs.odooAddons.l10n-br-fiscal
        pkgs.odooAddons.l10n-br-fiscal-certificate
        pkgs.odooAddons.l10n-br-fiscal-dfe
        pkgs.odooAddons.l10n-br-fiscal-edi
        pkgs.odooAddons.l10n-br-fiscal-notification
        pkgs.odooAddons.l10n-br-hr
        pkgs.odooAddons.l10n-br-hr-contract
        pkgs.odooAddons.l10n-br-mdfe-spec
        pkgs.odooAddons.l10n-br-mis-report
        pkgs.odooAddons.l10n-br-nfe-spec
        pkgs.odooAddons.l10n-br-nfse
        pkgs.odooAddons.l10n-br-nfse-focus
        pkgs.odooAddons.l10n-br-sped-base
        pkgs.odooAddons.l10n-br-zip
      ];
    };
  };
}

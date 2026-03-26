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
      package = pkgs.odoo19;
      domain = "redcom.digital";
      settings = {
        options = {
          http_port = 8011; 
          listen_addresses = "localhost, 192.168.13.20";
          db_host = "localhost";
          db_port = 5432;
          db_user = "odoo";
          # Use age para a senha (comente a linha abaixo e descomente a segura)
          admin_password = config.age.secrets.odoo-databasekey.path;
          db_password = config.age.secrets.odoo-databasekey.path;
          # db_password = "odoo";          # ⚠️ Temporário
          list_db = true;                # Habilita gerenciador web (opcional)
          proxy_mode = true;             # Necessário para confiar nos cabeçalhos
          dbfilter = ".*";               # Filtro global permissivo
          server_wide_modules = "base, web, dbfilter_from_header";
          # Evita banco padrão "odoo" que causa erros de tabela inexistente
          db_name = false;

          # Configurações de Performance
          limit_memory_hard = 1677721600;
          limit_memory_soft = 629145600;
          limit_request = 8192;
          limit_time_cpu = 600;
          limit_time_real = 1200;
          max_cron_threads = 1;
          workers = 8;
        };

      };
      autoInit = true;
      addons = with pkgs.odooAddons; [
        # Módulos base / infraestrutura / sequencias
        bus-alt-connection
        dbfilter-from-header
        sequence-python
        base-sequence-option
        # account-sequence-option
        # purchase-sequence-option

        # Módulos multi‑empresa (inter‑company e multi‑company)
        account-invoice-inter-company
        account-multicompany-easy-creation
        base-multi-company
        calendar-event-multi-company
        calendar-event-type-multi-company
        crm-lost-reason-multi-company
        crm-stage-multi-company
        crm-tag-multi-company
        hr-employee-multi-company
        ir-filters-multi-company
        ir-ui-view-multi-company
        login-all-company
        mail-multicompany
        mail-template-multi-company
        partner-category-multi-company
        partner-multi-company
        pos-category-multicompany
        product-multi-company
        product-multi-company-stock
        product-tax-multicompany-default
        purchase-sale-inter-company
        purchase-sale-stock-inter-company
        res-company-active
        res-company-category
        res-company-code
        res-company-search-view
        res-partner-industry-multi-company
        utm-medium-multi-company
        utm-source-multi-company

        # Módulos de localização brasileira (l10n_br)
        l10n-br-account-due-list
        l10n-br-account-payment-order
        l10n-br-base
        l10n-br-base-l10n-br-compat
        l10n-br-cnpj-search
        l10n-br-coa
        l10n-br-crm
        l10n-br-crm-cnpj-search
        l10n-br-cte-spec
        l10n-br-currency-rate-update
        l10n-br-fiscal
        l10n-br-fiscal-certificate
        l10n-br-fiscal-dfe
        l10n-br-fiscal-edi
        l10n-br-fiscal-notification
        l10n-br-hr
        l10n-br-hr-contract
        l10n-br-mdfe-spec
        l10n-br-mis-report
        l10n-br-nfe-spec
        l10n-br-nfse
        l10n-br-nfse-focus
        l10n-br-sped-base
        l10n-br-zip

        # Outros módulos (diversos)
        base-fontawesome
        base-fontawesome-web-editor
        base-name-search-improved
        partner-statement
      ];
    };
  };
}

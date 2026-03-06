{ config, pkgs, lib, inputs, options, ... }:

let
  sources = import ../../../npins;
  wp4nix = pkgs.callPackages sources.wp4nix {};

  app = "red";
  name = "cutms";
  domain = "${name}.org.br";
in

{
  services = {
    # Configuração do Traefik no servidor galactica (proxy reverso com SSL)
    traefik.dynamicConfigOptions = lib.mkIf (config.networking.hostName == "galactica") {
      http = {
        routers = {
          WP-CMS = {
            rule = "Host(`${domain}`)";
            service = "wordpress-server";
            entrypoints = ["websecure"];
            tls.certResolver = "cloudflare";
          };
        };
        services = {
          wordpress-server = {
            loadBalancer = {
              # Comunicação interna com o servidor pegasus na porta 7770 (HTTP)
              servers = [{ url = "http://pegasus.wcbrpar.com:7770"; }];
              passHostHeader = true;
            };
          };
        };
      };
    };

    # Configuração do PHP-FPM no servidor pegasus
    phpfpm.pools = lib.mkIf (config.networking.hostName == "pegasus") {
      "wordpress-${domain}".phpOptions = ''
        upload_max_filesize = 128M
        post_max_size = 128M
        memory_limit = 256M
      '';
    };

    # Configuração do WordPress no servidor pegasus
    wordpress = lib.mkIf (config.networking.hostName == "pegasus") {
      webserver = "nginx";   # Habilita gerenciamento do nginx pelo módulo
      sites = {
        "${domain}" = {
          package = pkgs.wordpress;
          database = {
            createLocally = true;
            name = "wpdb_${name}";
          };
          plugins = {
            inherit (pkgs.wordpressPackages.plugins)
              co-authors-plus
              simple-mastodon-verification
              surge
              wordpress-seo
              webp-converter-for-media
            ;
            inherit (wp4nix.plugins)
              antispam-bee
              async-javascript
              code-syntax-block
              custom-post-type-ui
              disable-xml-rpc
              google-site-kit
              notification
              official-facebook-pixel
              opengraph
              rss-importer
              static-mail-sender-configurator
              webp-express
              wpforms-lite
              wp-gdpr-compliance
              wp-user-avatars
              wp-rss-aggregator
              wp-swiper
            ;
          };
          themes = {
            inherit (pkgs.wordpressPackages.themes) twentytwentythree;
            inherit (wp4nix.themes) astra;
          };
          languages = [ wp4nix.languages.pt_BR ];
          settings = {
            WP_DEFAULT_THEME = "twentytwentythree";
            WP_MAIL_FROM = "gcp-devops@wcbrpar.com";
            WP_SITEURL = "https://${domain}";
            WP_HOME = "https://${domain}";
            WPLANG = "pt_BR";
            AUTOMATIC_UPDATER_DISABLED = true;
            FORCE_SSL_ADMIN = false;
            WP_DEBUG = true;
            WP_DEBUG_LOG = true;
            WP_DEBUG_DISPLAY = false;
          };
          extraConfig = ''
            @ini_set( 'error_log', '/var/log/wordpress/${domain}/debug.log' );
            @ini_set( 'display_errors', 1 );
          '';
          poolConfig = {
            "pm" = "dynamic";
            "pm.max_children" = 64;
            "pm.start_servers" = 2;
            "pm.min_spare_servers" = 2;
            "pm.max_spare_servers" = 4;
            "pm.max_requests" = 500;
          };

          # Configuração completa do virtualHost (substitui a padrão)
          virtualHost = {
            # Listen na porta 7770 (comunicação interna com Traefik)
            # Usando sintaxe estruturada: ip, port, ssl (ssl false = HTTP)
            listen = [
              {
                ip = "0.0.0.0";
                port = 7770;
                ssl = false;   # HTTP simples
              }
            ];

            # Desabilitar SSL (quem termina é o Traefik)
            enableACME = false;
            addSSL = false;
            forceSSL = false;  # Opcional, para evitar redirecionamento HTTPS

            # Locations personalizadas
            locations = {
              # Para requisições à raiz: tenta arquivo estático, senão passa para o WordPress
              "/" = {
                tryFiles = "$uri $uri/ /index.php?$args";
              };

              # Processamento de PHP (sobrescreve a padrão para incluir CSP e APP_ENV)
              "~ \\.php$" = {
                extraConfig = ''
                  fastcgi_split_path_info ^(.+\.php)(/.+)$;
                  fastcgi_pass unix:${config.services.phpfpm.pools."wordpress-${domain}".socket};
                  fastcgi_index index.php;
                  include ${pkgs.nginx}/conf/fastcgi_params;
                  fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                  fastcgi_param PATH_INFO $fastcgi_path_info;
                  fastcgi_param APP_ENV dev;
                  # Cabeçalhos CSP para todas as páginas PHP
                  more_set_headers "Content-Security-Policy: default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: https:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https: data: blob:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: https: *.gravatar.com; font-src 'self' https: data:; connect-src 'self' https:;";
                '';
              };

              # Tratamento especial para PDFs (inline)
              "~* (.*\\.pdf)" = {
                extraConfig = ''
                  types { application/pdf .pdf; }
                  default_type application/pdf;
                  more_set_headers Content-Disposition "inline" always;
                  more_set_headers X-Content-Type-Options "nosniff";
                  expires 30d;
                  more_set_headers Cache-Control "public, no-transform" always;
                  proxy_hide_header Content-Disposition;
                  proxy_hide_header X-Content-Type-Options;
                  proxy_ignore_headers Set-Cookie;
                  proxy_set_header Connection "";
                '';
              };

              # Área administrativa (CSP mais restritivo)
              "~ ^/(wp-admin|wp-login\\.php)" = {
                extraConfig = ''
                  more_set_headers "Content-Security-Policy: default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: https: *.gravatar.com; font-src 'self' https: data:; connect-src 'self' https:;";
                '';
              };

            };

            # Configuração do robots.txt via opção específica (gera o location automaticamente)
            robotsEntries = ''
              User-agent: *
              Disallow: /feed/
              Disallow: /trackback/
              Disallow: /wp-admin/
              Disallow: /wp-content/
              Disallow: /wp-includes/
              Disallow: /xmlrpc.php
              Disallow: /wp-
            '';

            # ExtraConfig pode ser usado para outras diretivas, se necessário
            extraConfig = "
              error_reporting(E_ALL);
              ini_set('display_errors', 1);
              ini_set('log_errors', 1);
            ";
          };
        };
      };
    };

    # VirtualHost adicional para subdomínio red.cutms.org.br (redireciona)
    # Como não faz parte do WordPress, mantemos no nginx.virtualHosts
    nginx.virtualHosts = lib.mkIf (config.networking.hostName == "pegasus") {
      "${app}.${domain}" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 7770;
          }
        ];
        serverName = "${app}.${domain}";
        globalRedirect = "${domain}";
      };
    };
  };
}

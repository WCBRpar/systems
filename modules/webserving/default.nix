{ config, pkgs, lib, ... }:

{

  # Nginx webserver
  services.nginx = {
    enable = true;
    logError = "stderr info";

    # Use recommended settings
    recommendedBrotliSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    experimentalZstdSettings = true;

    # Only allow PFS-enabled ciphers with AES256
    sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";

    # Log real IPs behind CDNs
    commonHttpConfig =

      let

        realIpsFromList = lib.strings.concatMapStringsSep "\n" (x: "set_real_ip_from  ${x};");
        fileToList = x: lib.strings.splitString "\n" (builtins.readFile x);
        cfipv4 = fileToList (pkgs.fetchurl {
          url = "https://www.cloudflare.com/ips-v4";
          sha256 = "0ywy9sg7spafi3gm9q5wb59lbiq0swvf0q3iazl0maq1pj1nsb7h";
        });
        cfipv6 = fileToList (pkgs.fetchurl {
          url = "https://www.cloudflare.com/ips-v6";
          sha256 = "1ad09hijignj6zlqvdjxv7rjj8567z357zfavv201b9vx3ikk7cy";
        });

      in

      ''
        ${realIpsFromList cfipv4}
        ${realIpsFromList cfipv6}
        real_ip_header CF-Connecting-IP;
      '';
    appendHttpConfig = ''
      # Add HSTS header with preloading to HTTPS requests.
      # Adding this header to HTTP requests is discouraged
      map $scheme $hsts_header {
        https   "max-age=31536000; includeSubdomains; preload";
      }
      add_header Strict-Transport-Security $hsts_header;

      # Enable CSP for your services.
      # Remocao temporaria em funcao de erros no wordpress 
      # add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
  
      # Minimize information leaked to other domains
      add_header 'Referrer-Policy' 'origin-when-cross-origin';
      
      # Disable embedding as a frame
      add_header X-Frame-Options DENY;
  
      # Prevent injection of code in other mime types (XSS Attacks)
      add_header X-Content-Type-Options nosniff;

      # This might create errors
      proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
    '';

    clientMaxBodySize = "20M";

    # Host comum para imagens estáticas auxiliaŕes a alguns módulos
    virtualHosts = {

      # Configuração para evitar que um site seja usado como padrão
      "_default" = {
        listen = [ { addr = "0.0.0.0"; port = 7770; ssl = false; } ];
        default = true;
        locations."/" = { return = 444; };
      };

      "img.redcom.digital" = lib.mkIf (config.networking.hostName == "pegasus") {
        serverAliases = [ "img.wcbrpar.com" ];
        root = "/var/lib/www/shared/images";
        listen = [ 
          { addr = "0.0.0.0"; port = 80; }   # HTTP
          # { addr = "0.0.0.0"; port = 443; } # HTTPS
        ];
        # forceSSL = true;
        # useACMEHost = "redcom.digital";

        extraConfig = ''
          add_header Referrer-Policy "origin-when-cross-origin" always;
          add_header X-Frame-Options "DENY" always;
          add_header X-Content-Type-Options "nosniff" always;
          add_header Cache-Control "public";
        '';

        locations."= /" = {
          return = "301 https://redcom.digital";
        };

        locations."/" = {
          tryFiles = "$uri =404";
          extraConfig = ''
            expires 30d;
            access_log off;
          '';
        };
      };
    };
  };

}


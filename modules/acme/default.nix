{ config, pkgs, lib, ... }:

{
  # TLS using ACME
  security.acme = {
    acceptTerms = true;
    defaults.email = "gcp-devops@wcbrpar.com";

    certs."iam.wcbrpar.com" = {
      webroot = "/var/lib/acme/iam.wcbrpar.com";
      email = "gcp-devops@wcbrpar.com";
      # Ensure that the web server you use can read the generated certs
      # Take a look at the group option for the web server you choose.
      group = "nginx";
      # Since we have a wildcard vhost to handle port 80,
      # we can generate certs for anything!
      # Just make sure your DNS resolves them.
      # extraDomainNames = [ "walcor.com.br" "redcom.digital" ];
    };
  };

  # /var/lib/acme/.challenges must be writable by the ACME user
  # and readable by the Nginx user. The easiest way to achieve
  # this is to add the Nginx user to the ACME group.
  users.users.nginx.extraGroups = [ "acme" ];

  # Nginx webserver
  services.nginx = {
    virtualHosts = {

      "iam.wcbrpar.com" = {
        default = true;
        # forceSSL = true; 
        addSSL = true;
        useACMEHost = "iam.wcbrpar.com";
        # Catchall vhost, will redirect users to HTTPS for all vhosts
        # All serverAliases will be added as extra domain names on the certificate.
        serverAliases = [ "*.iam.wcbrpar.com" ];
        locations."/.well-known/acme-challenge" = {
          root = "/var/lib/acme/iam.wcbrpar.com";
        };
        locations."/" = {
          root = "/var/www/WPR";
          extraConfig = ''
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:${config.services.phpfpm.pools."iam.wcbrpar.com".socket};
            include ${pkgs.nginx}/conf/fastcgi_params;
            include ${pkgs.nginx}/conf/fastcgi.conf;
          '';
        };
        locations."/" = {
          proxyPass = "http://localhost:8096";
        };
      };

      "iam.wcbrpar.com80" = {
        serverName = "iam.wcbrpar.com";
        serverAliases = [ "*.iam.wcbrpar.com" ];
        locations."/.well-known/acme-challenge" = {
          root = "/var/lib/acme/iam.wcbrpar.com";
          extraConfig = ''
            auth_basic off;
          '';
        };
        locations."/" = { return = "301 https://$host$request_uri"; };
        listen = [{ addr = "0.0.0.0"; port = 80; } { addr = "[::0]"; port = 80; }];
      };

    };
  };

  services.phpfpm.pools."iam.wcbrpar.com" = {
    user = "nginx";
    group = "nginx";
    settings = {
      "listen.owner" = config.services.nginx.user;
      "listen.group" = config.services.nginx.group;
      "listen.mode" = "0600";
      "pm" = "dynamic";
      "pm.max_children" = 75;
      "pm.start_servers" = 10;
      "pm.min_spare_servers" = 5;
      "pm.max_spare_servers" = 20;
      "pm.max_requests" = 500;
      "catch_workers_output" = 1;
    };
    phpOptions = ''
      date.timezone = "America/Campo_Grande"
      upload_max_filesize = 128M
      post_max_size = 20M
      memory_limit = 256M
    '';
  };

}


{ config, pkgs, lib, ... }:

with lib;

let

  mailAccounts = config.mailserver.loginAccounts;
  htpasswd = pkgs.writeText "radicale.users" (concatStrings
    (flip mapAttrsToList mailAccounts (mail: user:
      mail + ":" + user.hashedPassword + "\n"
    ))
  );

in

{

  services.radicale = lib.mkIf ( config.networking.hostName == "galactica" ) {
    enable = true;
    settings = {
      auth = {
        type = "htpasswd";
        htpasswd_filename = "${htpasswd}";
        htpasswd_encryption = "bcrypt";
      };
      server = {
        hosts = [ "0.0.0.0:5232" "[::]:5232" ];
      };
      storage = {
        filesystem_folder = "/var/lib/radicale/collections";
      };
    };
  };

#  services.nginx = lib.mkIf ( config.networking.hostName == "galactica" ) {
#    enable = true;
#    virtualHosts = {
#      "cal.redcom.digital" = {
#        forceSSL = true;
#        enableACME = true;
#	locations."/.well-know/acme-challenge" = {
#	  root = "/var/lib/acme/cal.redcom.digital";
#	};
#	 
#        locations."/" = {
#          proxyPass = "http://cal.redcom.digital:5232/";
#          extraConfig = ''
#            proxy_set_header  X-Script-Name /;
#            proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
#            proxy_pass_header Authorization;
#          '';
#        };
#      };
#
#      "cal.wcbrpar.com" = {
#        globalRedirect = "cal.redcom.digital";
#	forceSSL = false;
#      };
#    };
#  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.traefik.dynamicConfig.http.routers = lib.mkIf ( config.networking.hostName == "galactica" ) {
    "radicale-redcom" = {
      entryPoints = [ "web" "websecure" ];
      rule = "Host(`cal.redcom.digital`)";
      service = "radicale-redcom";
      middlewares = [ "redirect-to-https" ];
    };
    "radicale-redcom-secure" = {
      entryPoints = [ "websecure" ];
      rule = "Host(`cal.redcom.digital`)";
      service = "radicale-redcom";
      tls = {
        certResolver = "cloudflare";
      };
    };
    "radicale-wcbrpar" = {
      entryPoints = [ "web" "websecure" ];
      rule = "Host(`cal.wcbrpar.com`)";
      service = "radicale-redcom"; # Redireciona para o mesmo serviço
      middlewares = [ "redirect-to-https" ];
    };
    "radicale-wcbrpar-secure" = {
      entryPoints = [ "websecure" ];
      rule = "Host(`cal.wcbrpar.com`)";
      service = "radicale-redcom"; # Redireciona para o mesmo serviço
      tls = {
        certResolver = "cloudflare";
      };
    };
  };

  services.traefik.dynamicConfig.http.services = lib.mkIf ( config.networking.hostName == "galactica" ) {
    "radicale-redcom" = {
      loadBalancer.servers = [
        {
          url = "http://127.0.0.1:5232";
        }
      ];
    };
  };
}


{ config, pkgs, lib, ... }:

{
  services.nginx = lib.mkIf (config.networking.hostName == "pegasus") {
    virtualHosts = {
      "img.redcom.digital" = {
        serverAliases = [ "img.wcbrpar.com" ];
        root = "/var/lib/www/shared/images";
        
        # Forçar HTTPS
        forceSSL = true;
        useACMEHost = "redcom.digital";

	extraConfig = ''
          # Segurança
          # add_header Strict-Transport-Security "max-age=31536000; includeSubdomains; preload" always;
          add_header Referrer-Policy "origin-when-cross-origin" always;
          add_header X-Frame-Options "DENY" always;
          add_header X-Content-Type-Options "nosniff" always;
          
          # Cache
          add_header Cache-Control "public";
        '';

        locations = {
          "= /" = {
            return = "301 https://redcom.digital";
            # Cabeçalhos específicos para o redirecionamento
            extraConfig = ''
              # add_header Cache-Control "no-cache, no-store, must-revalidate";
              # expires 0;
	    '';
          };
          
          "/" = {
            tryFiles = "$uri =404";
            extraConfig = ''
              expires 30d;
              access_log off;
            '';
          };
        };
      };
    };
  };
}

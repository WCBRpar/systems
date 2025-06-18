{ config, lib, pkgs, ... }:

{

  environment.systemPackages = with pkgs; [ onlyoffice-documentserver ];

  services = lib.mkIf ( config.networking.hostName == "galactica" ) {

    traefik = {
      dynamicConfigOptions = {
        http = {
	  routers = {
	    onlyoffice = {
	      rule = "Host(`office.wcbrpar.com`)";
	      service = "onlyoffice-service";
	      entrypoints = ["websecure"];
	      tls = {
		certResolver = "cloudflare";
	      };
	    };
	  };
	  services = {
	    onlyoffice-service = {
	      loadbalancer = {
	        servers = [{ url = "https://127.0.0.1:8009"; }];
		passHostHeader = true;
	      };
	    };
	  };
	};
      };
    };

    onlyoffice = {
      port = 8008;
      enable = true;
      hostname = "office.wcbrpar.com";
    };
    nginx.virtualHosts."office.wcbrpar.com" = {
      extraConfig = ''
        # Force nginx to return relative redirects. This lets the browser
        # figure out the full URL. This ends up working better because it's in
        # front of the reverse proxy and has the right protocol, hostname & port.
        absolute_redirect off;
      '';
      listen = [
        {
          port = 8009;
          addr = "127.0.0.1";
        }
      ];
    };
  };


}

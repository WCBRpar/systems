{ config, lib, pkgs, ... }:

{

  environment.systemPackages = with pkgs; [ onlyoffice-documentserver ];

  services = lib.mkIf ( config.networking.hostName == "galactica" ) {

    traefik = {
      dynamicConfigOptions = {
        http = {
	  routers = {
	    onlyoffice = {
	      rule = "Host(`office.wcbrpar.com`) && (PathPrefix(`/`))";
	      service = "onlyoffice-service";
	      entrypoints = ["websecure"];
	      tls = {
		certResolver = "cloudflare";
	      };
	      # middlewares = ["onlyoffice-prefix"];
	    };
	  };
	  services = {
	    onlyoffice-service = {
	      loadBalancer = {
	        servers = [{ url = "http://127.0.0.1:8008"; }];
		passHostHeader = true;
		healthCheck = {
		  path = "/healthcheck/";
		  interval = "10s";
		  timeout = "3s";
		};
	      };
	    };
	  };
	  middlewares = {
	    onlyoffice-prefix = {
	      stripPrefix.prefixes = ["/"];
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
        # absolute_redirect off;
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

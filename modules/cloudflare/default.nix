{ config, pkgs, ... }:

{
  services.cloudflared = {
    enable = true;
    tunnels = {
      "97b3bfc5-de43-4690-9c9e-861834ded8f7" = { # pegasus@skynet
        default = "http_status:404";
        ingress = {
          "*.wcbrpar.com" = "http://localhost:80";
	  "*.redcom.digital" = "http://localhost:80";
        };
        credentialsFile = "/var/lib/cloudflared/pegasus@skynet.json";
      };
    };
  };
}

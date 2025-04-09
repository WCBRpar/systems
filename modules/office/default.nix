{ config, pkgs, ... }:

{

  environment.systemPackages = with pkgs; [ onlyoffice-documentserver ];

  # Habilitar o Docker
  virtualisation.docker.enable = true;

  services = {
    onlyoffice = {
      port = 8008;
      enable = false;
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

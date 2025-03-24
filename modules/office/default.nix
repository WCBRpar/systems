{ config, pkgs, ... }:

{

  environment.systemPackages = with pkgs; [ onlyoffice-documentserver ];

  # Habilitar o Docker
  virtualisation.docker.enable = true;

  services.onlyoffice = {
    enable = true;
    hostname = "office.wcbrpar.com";
  };

}

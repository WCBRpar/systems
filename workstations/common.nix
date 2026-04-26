{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{

  # Configurações de rede
  networking.networkmanager.enable = true; 
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Auto-upgrade do sistema
  system = {
    autoUpgrade.enable = true;
    stateVersion = "24.11";
  };
}

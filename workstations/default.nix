{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager

  ];

  # Configurações de rede
  networking.networkmanager.enable = true; 
  services.openssh.settings.PasswordAuthentication = true;
  services.openssh.settings.PermitRootLogin = "no";

  # Auto-upgrade do sistema
  system.autoUpgrade.enable = true;
  system.stateVersion = "24.11";
}

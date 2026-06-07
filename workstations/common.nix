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

  programs = {
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  # Auto-upgrade do sistema
  system = {
    autoUpgrade.enable = true;
    stateVersion = "24.11";
  };

  # Garbage Collection Automation and Disk Usage Otimization
  nix = {
    gc = { 
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    settings.auto-optimise-store = true;
    extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
  };

  services.journald.extraConfig = ''
    SystemMaxUse=2G
  '';

}

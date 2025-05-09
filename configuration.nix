{ config, pkgs, ... }:

let

  sources = import ./npins;

in

{
  nixpkgs.config.permittedInsecurePackages = [ 
    "jitsi-meet-1.0.8043"
    "kanidm-1.4.6"
  ];

  imports = [
    <agenix/modules/age.nix>
    <home-manager/nixos>
    ./vpsadminos.nix
    ./modules
    ./networking
    ./storage
    ./users
  ];

  # Pacotes e variáveis necessárias ao sistema
  environment.systemPackages = with pkgs; [ 
    (pkgs.callPackage <agenix/pkgs/agenix.nix> {})
    home-manager
  ];

  systemd.extraConfig = ''
    DefaultTimeoutStartSec=900s
  '';

  # Fuso horário do sistema
  time.timeZone = "America/Campo_Grande";

  # Compatibilidade da versão do sistema
  system.stateVersion = "24.11";

  # Atualizaçã́o automática?
  system.autoUpgrade.enable = true;

  # Limpeza automática do sistema
  services.journald.extraConfig = ''
    SystemMaxUse=2G
  '';

  nix = {
    extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    settings = {
      auto-optimise-store = true;
      # Ativar Flakes
      experimental-features = ["nix-command" "flakes"];
      keep-derivations = true;
      keep-outputs = true;
    };
  };

  # Pacotes proprietários - Preciso para o ZeroTier 1 -  Procurar substituto
  nixpkgs.config.allowUnfree = true;

}

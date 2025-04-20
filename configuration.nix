{ config, pkgs, ... }:
<<<<<<< HEAD

let

  sources = import ./npins;

in

=======
>>>>>>> main
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
  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 30d";
  nix.settings.auto-optimise-store = true;
  nix.extraOptions = ''
    min-free = ${toString (100 * 1024 * 1024)}
    max-free = ${toString (1024 * 1024 * 1024)}
  '';
  services.journald.extraConfig = ''
    SystemMaxUse=2G
  '';

  # Ativar Flakes
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Pacotes proprietários - Preciso para o ZeroTier 1 - Procurar substituto
  nixpkgs.config.allowUnfree = true;

}

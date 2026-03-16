{ config, pkgs, ... }:

{
  # Naming-scheme - https://namingschemes.com/Battlestar_Galactica

  imports = [ ../modules/host-id ];

  my.host = {
    name = "pegasus"; # Naming-scheme: https://namingschemes.com/Battlestar_Galactica
    id = "8bf0dda5";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZMl3IL3fzhwLirgKiPKEaATdwRKk5ZBYFJw57uCQO4 root@nixos";
    sshPrivateKeyFile = ../secrets/host-pegasus-key.age; # se for gerenciar a chave privada
    ztc25hlssg = {
      address = "192.168.13.20/24"; # IP interno para a interface ZeroTier
    };
  };

  # Outras configurações específicas do host...
}


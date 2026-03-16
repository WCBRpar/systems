{ config, pkgs, ... }:

{
  imports = [ ../modules/host-id ];

  my.host = {
    name = "yashuman";    # Naming-scheme: https://namingschemes.com/Battlestar_Galactica
    id = "e491eb5c";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIQ9DhL5m2ofBk0mnAG53h2TGR1s1wxaDTWA+w+bASVJ root@nixos";
    sshPrivateKeyFile = ../secrets/host-yashuman-key.age;   # se for gerenciar a chave privada
    ztc25hlssg = {
      address = "192.168.13.130/24";   # IP interno para a interface ZeroTier
    };
  };

  # Outras configurações específicas do host...
}

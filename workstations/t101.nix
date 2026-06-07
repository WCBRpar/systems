{
  config,
  pkgs,
  ...
}:
{
  networking.hostId = "141ec2b6"; # ID único para T800
  networking.hostName = "T101";

  imports = [
    ./default.nix
  ];

  # Configurações específicas do hardware (já incluídas em workstations/default.nix via nixos-hardware)
  # nixos-hardware/lenovo/ideapad/s145-15api

  # Usuários referenciado do LDAP, não criado localmente
  # A configuração do usuário e home-manager está em workstations/default.nix

  # Outras configurações específicas para T101, se houver
}

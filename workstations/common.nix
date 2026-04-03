{
  config,
  pkgs,
  ...
}:
{
  networking.hostId = "d00dbeef"; # ID único para T800
  networking.hostName = "t800";

  imports = [
    ./default.nix
  ];

  # Configurações específicas do hardware (já incluídas em workstations/default.nix via nixos-hardware)
  # nixos-hardware/lenovo/ideapad/s145-15api

  # Usuário caroles (referenciado do LDAP, não criado localmente)
  # A configuração do usuário 'caroles' e home-manager está em workstations/default.nix

  # Outras configurações específicas para T800, se houver
}

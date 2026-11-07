{ ... }:

let
  identityIds = import ./identity-ids.nix;
in
{
  security.sudo.wheelNeedsPassword = false;
  security.sudo.extraConfig = "Defaults env_keep += SSH_AUTH_SOCK";

  # Grupo de administradores separado dos grupos privados dos usuários.
  users.groups.admins.gid = identityIds.groups.admins;

  # Grupo comum de autorização Unix para a futura autenticação via Kanidm.
  users.groups."unix-users".gid = identityIds.groups.unixUsers;

  # Grupos privados: os GIDs coincidem com os UIDs e com o gidNumber Kanidm.
  users.groups.wjjunyor.gid = identityIds.persons.wjjunyor.gidNumber;
  users.groups.caroles.gid = identityIds.persons.caroles.gidNumber;

  # root permanece uma conta local de recuperação/administrativa; não é Kanidm.
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICn5PEy7qX9HZ+NkKAFV+CAgydvXe57kmesBdZHja5d7 dev-ops@wcbrpar.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzdmKZQGZOSI1denOeN3kso6Lf/OL92QXN5SHXA7EtG walter@wcbrpar.com"
    ];
  };

  users.users.wjjunyor = {
    isNormalUser = true;
    createHome = true;
    home = "/home/wjjunyor";
    description = "Walter Queiroz";
    uid = identityIds.persons.wjjunyor.uid;
    group = "wjjunyor";
    extraGroups = [
      "users"
      "admins"
      "unix-users"
      "wheel"
      "disk"
      "audio"
      "video"
      "networkmanager"
      "systemd-journal"
      "adbusers"
      "scanner"
      "lp"
    ];
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [
      # "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCf4fFLxzNzdOisQPhuoh4M/aYJFavXVJOZNOhpFgiX3OjdbQPVXV7z1x+dzD9/Vobd/UlM8mlZYwu0dDJWe2KA3MoBQ0MRRdqGwED/jF/BWj+DoIXPlFqdG8eMFn7zWKDYh9FUH/uhUcs1xAc1KYcC45PHQZR4rvZP0cCwurpKBtqUaIX0uJLswQDQ+xAYXzF3VJ00ghv9Wfmus+PyDMTZyCvkp5a33+zv0wBdXvBf6xSBUiohH2A1Y2yQ3hKyiO9Waaq6ERNY3TTP+4G/znw/zm33Sp5PVeNhADFQk5jEXu5FqRIbIglcRpyFU8q4Zrsxlw7QXZfOua2YitMu5k95 walter_wcbrpar_com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzdmKZQGZOSI1denOeN3kso6Lf/OL92QXN5SHXA7EtG walter@wcbrpar.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICn5PEy7qX9HZ+NkKAFV+CAgydvXe57kmesBdZHja5d7 dev-ops@wcbrpar.com"
    ];
  };

  users.users.caroles = {
    isNormalUser = true;
    createHome = true;
    home = "/home/caroles";
    description = "Carolina Queiroz";
    uid = identityIds.persons.caroles.uid;
    group = "caroles";
    # Mantém `users` como grupo suplementar durante a transição do grupo primário.
    extraGroups = [
      "users"
      "admins"
      "unix-users"
      "wheel"
      "disk"
      "audio"
      "video"
      "networkmanager"
      "systemd-journal"
      "adbusers"
    ];
    useDefaultShell = true;
  };
}

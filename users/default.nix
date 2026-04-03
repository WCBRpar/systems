{...}: 

{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  security.sudo.wheelNeedsPassword = false;
  security.sudo.extraConfig = "Defaults env_keep += SSH_AUTH_SOCK";

  users.groups.admins = {
    gid = 1000;
  };

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
    uid = 1000;
    group = "admins";
    extraGroups = [ "users" "wheel" "disk" "audio" "video" "networkmanager" "systemd-journal" "adbusers" "scanner" "lp" ];
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
    uid = 2000;
    group = "users";
    extraGroups = ["wheel" "disk" "audio" "video" "networkmanager" "systemd-journal" "adbusers"];
    useDefaultShell = true;
  };

}

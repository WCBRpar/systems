{...}: 

{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  security.sudo.wheelNeedsPassword = false;
  
  users.groups.admins = {
    gid = 1000;
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

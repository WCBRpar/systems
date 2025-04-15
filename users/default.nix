{...}: 

{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  security.sudo.wheelNeedsPassword = false;
  
  users.groups.admins = {};

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
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDlE3hqwUhIDnitfyYhU2LnulduhSYl9XJDCf/XrV8LL5hkSt6HSj0WEh1Pn1AJyW5C77WMB+BcmviakKTNlwijVYIu64S24lJjfB60SN/XzzEoQiloXrTGSqhokz9J8Usj3VIMeNLV3lyFiv0nX4ZiPrcBeDzK8a5Cxrf17POiwQjRjrRoVxZ8iNOu8Oo0hEFvhqnuuPDbwnE+dJ4tpwSnyBSweeMRYXKBf1SLK4E3TeLPXxhzKvuTZhnzXLHJ6qx3WKWjkPI6gE9cjFn5sopsWq2ZWXkJTs2+ePdQJinG9IY+D5wKwOLTPNZhuvpwinHvXV9IhBlhHukm8X3i82h6644slX9pcMYC4zrk+etz4Idko51PySLf7hKElXpD7E6PhnY5LyMvaeol9Lqpz8v1Ar1TGJtmdTG9O39w4kvE4QoSQL/Z1zNdchmvglt/AW9m0YuoG3K29QNWBHPnDdlKHcXA+viuwxdU7TotYzjqGwWzG6JwLqsAPn626YNW4XU= wjjunyor@T101"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCf4fFLxzNzdOisQPhuoh4M/aYJFavXVJOZNOhpFgiX3OjdbQPVXV7z1x+dzD9/Vobd/UlM8mlZYwu0dDJWe2KA3MoBQ0MRRdqGwED/jF/BWj+DoIXPlFqdG8eMFn7zWKDYh9FUH/uhUcs1xAc1KYcC45PHQZR4rvZP0cCwurpKBtqUaIX0uJLswQDQ+xAYXzF3VJ00ghv9Wfmus+PyDMTZyCvkp5a33+zv0wBdXvBf6xSBUiohH2A1Y2yQ3hKyiO9Waaq6ERNY3TTP+4G/znw/zm33Sp5PVeNhADFQk5jEXu5FqRIbIglcRpyFU8q4Zrsxlw7QXZfOua2YitMu5k95 walter_wcbrpar_com"
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

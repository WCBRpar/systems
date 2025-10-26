{ config, pkgs, ... }:

{
  fileSystems."/nas-data" = {
    device = "172.16.131.37:/nas/6116";
    fsType = "nfs";
    options = [ "nofail" ];
  };
  fileSystems."/mnt/export2394" = {
    device = "172.16.129.26:/nas/6116/users";
    fsType = "nfs";
    options = [ "nofail" ];
  };
}
		

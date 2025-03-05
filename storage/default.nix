{ config, pkgs, ... }:

{
  fileSystems."/nas-data" = {
    device = "172.16.131.37:/nas/6116";
    fsType = "nfs";
    options = [ "nofail" ];
  };
}
		

{ config, pkgs, ... }:

{
  fileSystems."/nas-data" = {
    device = "172.16.131.37:/nas/6116";
    fsType = "nfs";
    options = [ "nofail" ];
  };
  fileSystems."/home" = {
    device = "172.16.129.26:/nas/6116/users";
    fsType = "nfs";
    options = [ 
      "nofail"
      "rw"
      "sync"
      "hard"
      "timeo=600"
      "retrans=2"
      ];
  };
  
  systemd.services."home-mount" = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };
}
		

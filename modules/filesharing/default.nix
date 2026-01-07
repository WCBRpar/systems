{ config, lib, pkgs, ... }:

{
  fileSystems."/nas-data/home" = lib.mkIf ( config.networking.hostName <> "yashuman" ) {
    device = "172.16.129.26:/nas/6116/users";
    fsType = "nfs";
    options = [ "nofail" ];
  };

  services.nfs.server = lib.mkIf (config.networking.hostName == "yashuman") {
    enable = true;
    exports = ''
      /nas-data/home   192.168.13.0/24(rw,fsid=0,no_subtree_check)
    '';
  };

}

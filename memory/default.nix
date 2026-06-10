{ config, pkgs, lib, hostName, ... }: 

{
  zramSwap = lib.mkIf (hostName <> "yashuman") {
    enable = true;
    memoryPercent = 50;       # % da RAM dedicada ao zram
  };

}

{ config, pkgs, ... }:

{
  # Naming-scheme - https://namingschemes.com/Battlestar_Galactica

  networking.hostId = "e491eb5c"; # Yashuman      # cut -c-8 < /proc/sys/kernel/random/uuid
  networking.hostName = "yashuman";
}

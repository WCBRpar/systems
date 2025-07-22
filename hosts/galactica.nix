{ config, pkgs, ... }:

{
  # Naming-scheme - https://namingschemes.com/Battlestar_Galactica

  networking.hostId = "13960a97"; # Galactica      # cut -c-8 < /proc/sys/kernel/random/uuid
  networking.hostName = "galactica";
}

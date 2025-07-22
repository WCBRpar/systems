{ config, pkgs, ... }:

{
  # Naming-scheme - https://namingschemes.com/Battlestar_Galactica

  networking.hostId = "8bf0dda5"; # Pegasus      # cut -c-8 < /proc/sys/kernel/random/uuid
  networking.hostName = "pegasus";
}

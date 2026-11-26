{ config, lib, pkgs, hostName, ... }: 

let 

  # Importa as configurações de todos os hosts
  allHosts = import ../hosts/default.nix;

in

{
  services.nextcloud-spreed-signaling = lib.mkIf (hostName == "galactica") {
    enable = true;
    hostName = "talk.wcbrpar.com";
    # backends = {     };
  };
}

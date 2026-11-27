{ config, lib, pkgs, hostName, ... }: 

let 

  # Importa as configurações de todos os hosts
  allHosts = import ../hosts/default.nix;

in

{
  services.nextcloud-spreed-signaling = lib.mkIf (hostName == "galactica") {
    enable = true;
    hostName = "talk.wcbrpar.com";
    backends = {    
      main = {
        urls = [ "https://cloud.wcbrpar.com" "https://cloud.redcom.digital" "https://cloud.walcor.com.br" "https://cloud.wqueiroz.adv.br" ];
        secretFile = builtins.readFile config.age.secrets.nextcloud-signaling-backends-secret.path;
      };
    };
    settings = {
      sessions = {
        hashkeyFile = builtins.readFile config.age.secrets.nextcloud-signaling-sessions-haskey.path;
        blockkeyFile = builtins.readFile config.age.secrets.nextcloud-signaling-sessions-blockkey.path;
      };
      clients = {
        internalsecretFile = builtins.readFile config.age.secrets.nextcloud-signaling-clients-secret.path;
        http.liesten = "127.0.0.1:8062";
      };
      nats.url = "nats://loopback";

      turn = {
        apikeyFile = builtins.readFile config.age.secrets.nextcloud-signaling-turn-apikey.path;
        secretFile = builtins.readFile config.age.secrets.nextcloud-signaling-turn-secret.path;
        servers = [
          "turn:://wcbrpar.com"
          "turn:://redcom.digital"
          "turn:://walcor.com.br"
          "turn:://wqueiroz.adv.br"
        ];
      };
    };
  };

  age.secrets = {
    nextcloud-signaling-backends-secret = {
      file = ../../secrets/nextcloudSignaligBackendsSecret.age;
      owner = "nextcloud";
      group = "office";
      mode = "440";
    };

    nextcloud-signaling-sessions-hashkey = {
      file = ../../secrets/nextcloudSignaligSessionsHashkey.age;
      owner = "nextcloud";
      group = "office";
      mode = "440";
    };

    nextcloud-signaling-sessions-blockkey = {
      file = ../../secrets/nextcloudSignaligSessionsBlockkey.age;
      owner = "nextcloud";
      group = "office";
      mode = "440";
    };

    nextcloud-signaling-clients-secret = {
      file = ../../secrets/nextcloudSignaligClientsSecret.age;
      owner = "nextcloud";
      group = "office";
      mode = "440";
    };

    nextcloud-signaling-turn-apikey = {
      file = ../../secrets/nextcloudSignaligTurnApikey.age;
      owner = "nextcloud";
      group = "office";
      mode = "440";
    };

    nextcloud-signaling-turn-secret = {
      file = ../../secrets/nextcloudSignaligTurnSecret.age;
      owner = "nextcloud";
      group = "office";
      mode = "440";
    };
  };

}

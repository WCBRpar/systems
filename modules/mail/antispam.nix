{ config, lib, pkgs, hostName, ... }: 

{

  # Segredos para o Rspamd
  age.secrets = lib.mkIf ( hostName == "galactica" ) {
    rspamd-token = {
      file = ../../secrets/rspamdToken.age;
      owner = "root";
      group = "root";
      mode = "440";
    };
  };

  services = {

    rspamd = lib.mkIf (hostName == "galactica") {
      enable = true;
      workers.controller = {
        bindSockets = [
          {
            socket = "/run/rspamd/worker-controller.sock";
            mode = "0666";
          }
          {
            socket = "127.0.0.1:11334";
          }
        ];
        extraConfig = ''
          secure_ip = ["0.0.0.0/0", "::/0"];
          # password = config.age.secrets.rspamd-token.path;
          # enable_password = config.age.secrets.rspamd-token.path;
        '';
      };
    };

    traefik = lib.mkIf (hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            # RSpamd Interface
            RS-ALL = {
              rule = "Host(`rspamd.wcbrpar.com`) || Host(`rspamd.redcom.digital`) || Host(`rspamd.walcor.com.br`) || Host(`rspamd.wqueiroz.adv.br`) || Host(`wcbrpar.com`) ";
              service = "rspamd-service"; 
              entrypoints = ["websecure"];
              tls = {
                certResolver = "cloudflare";
              };
              # middlewares = [ "dashboard-redirect" "oidc-auth" ];
            };
          };
        services.rspamd-service.loadBalancer.servers = [ { url = "http://127.0.0.1:11334"; } ];
        };
      };
    };
  };
  

}

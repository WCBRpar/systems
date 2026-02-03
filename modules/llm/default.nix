{ config, lib,  ... }:

{

  services = {
    
    ollama = lib.mkIf ( config.networking.hostName == "yashuman" ) {
      enable = true;
      port = 11434;
      # Preload modules from Ollama Library: https://ollama.com/library
      loadModels = [ "deepseek-coder:1.3b" "deepseek-r1:1.5b"];
    };

    open-webui = lib.mkIf ( config.networking.hostName == "yashuman" ) {
      enable = true;
      port = 9999;
      host = "0.0.0.0";
    };

    traefik = lib.mkIf (config.networking.hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            AI-ALL = {
              rule = "Host(`ai.wcbrpar.com`) || Host(`ai.redcom.digital`)";
              service = "openwebui-service";
              entrypoints = ["websecure"];
              tls.certResolver = "cloudflare";
            };
          };
          
          services = {
            openwebui-service = {
              loadBalancer = {
                servers = [{ url = "http://yashuman.wcbrpar.com:9999"; }];
                passHostHeader = true;
              };
            };
          };
        };
      };
    };
  };
      
  networking.firewall = lib.mkIf ( config.networking.hostName == "yashuman" ) {
    allowedTCPPorts = [ 9999 ];
  };

}

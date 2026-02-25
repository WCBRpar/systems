{ config, lib, pkgs,  ... }:

{

  #Segredos
  age.secrets = {
    deepseek-apikey.file = ../../secrets/deepseekApiKey.age;
    openrouter-apikey.file = ../../secrets/openrouterApiKey.age;
    telegram-botkey.file = ../../secrets/telegramBotKey.age;
  };

  services = {

    pangolin = {
      enable = lib.mkForce false;  # Tentando resolver as cagadas no refactor do Traefik
    };

    picoclaw = lib.mkIf ( config.networking.hostName == "yashuman" ) {
      enable = true;
      model = "ollama/phi3:mini"; 
      providers = {
        deepseek = {
          api_key = builtins.readFile config.age.secrets.deepseek-apikey.path;
        };
        # openrouter = {
        #   api_key = builtins.readFile config.age.secrets.openrouter-apikey.path;
        # };
        ollama = {
          api_base = "http://yashuman.wcbrpar.com:11434/v1";
        };
      };
      channels = {
        telegram = {
          enable = true;
          token = builtins.readFile config.age.secrets.telegram-botkey.path;
          allow_from = [ 26396894 ];
        };
      };
    };


    ollama = lib.mkIf ( config.networking.hostName == "yashuman" ) {
      enable = true;
      package = pkgs.ollama-cpu;
      port = 11434;
      # Preload modules from Ollama Library: https://ollama.com/library
      loadModels = [ 
        "codellama:7b"
        "deepseek-coder:1.3b" 
        "deepseek-r1:1.5b"
        "phi3:mini"   
        "qwen2.5-coder:1.5b"
      ];
      environmentVariables = {
        OLLAMA_NUM_THREADS = "16"; 
        OLLAMA_CPU_ISA = "AVX2";
        OLLAMA_NICE = "-10";
        OLLAMA_KEEP_ALIVE = "5m";      
        OLLAMA_FLASH_ATTENTION = "0"; 
        OLLAMA_HOST = "0.0.0.0";
      };
      openFirewall = true;
    };

    open-webui = lib.mkIf ( config.networking.hostName == "pegasus" ) {
      enable = true;
      port = 9999;
      host = "0.0.0.0";
      openFirewall = true;
      environment = {
        OLLAMA_BASE_URL = "http://yashuman.wcbrpar.com:11434";
      };
    };

    traefik = lib.mkIf (config.networking.hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            "AI-ALL" = {
              rule = "Host(`ai.wcbrpar.com`) || Host(`ai.redcom.digital`)";
              service = "openwebui-service";
              entrypoints = ["websecure"];
              tls.certResolver = "cloudflare";
            };
          };
          
          services = {
            openwebui-service = {
              loadBalancer = {
                servers = [{ url = "http://pegasus.wcbrpar.com:9999"; }];
                passHostHeader = true;
              };
            };
          };
        };
      };
    };
  };
      
}

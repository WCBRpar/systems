{ config, lib, pkgs, ... }:

{
  services = {
    traefik = lib.mkIf (config.networking.hostName == "galactica") {
      enable = true;
      dynamicConfigOptions = {
        http = {
          routers = {
            JM-ALL = {
              rule = "Host(`meet.wcbrpar.com`) || Host(`meet.redcom.digital`)";
              service = "meet-service";
              entrypoints = ["websecure"];
              middlewares = [ "jitsi-headers"];
              tls = {
                certResolver = "cloudflare";
              };
            };
          };
          middlewares = {
            jitsi-headers = {
              customRequestHeaders = {
                "X-Forwarded-Proto" = "https";
              };
              customRespondeHeaders = {
                "Strict-Transport-Security" = "max-age=31536000; includeSubDomains";
              };
            };
          };
          services = {
            "meet-service" = {
              loadBalancer = {
                servers = [
                  { url = "http://galactica.wcbrpar.com:8010"; } # Jitsi-Meet na porta padrão
                ];
                passHostHeader = true;
              };
            };
          };
        };
      };
    };

    jitsi-meet = lib.mkIf (config.networking.hostName == "galactica") {
      enable = true;
      hostName = "meet.redcom.digital";
      
      # Desabilita o nginx do Jitsi-Meet pois o Traefik fará o proxy reverso
      nginx.enable = false;
      
      interfaceConfig = {
        APP_NAME = "meet@redcom.digital";
        DEFAULT_REMOTE_DISPLAY_NAME = "Convidado";
        BRAND_WATERMARK_LINK = "";
        DEFAULT_LOGO_URL = "https://img.redcom.digital/icon.svg";
        DEFAULT_WELCOME_PAGE_LOGO_URL = "https://img.redcom.digital/icon.svg";
        AUDIO_LEVEL_PRIMARY_COLOR = "rgba(221,42,42,0.4)";
        AUDIO_LEVEL_SECONDARY_COLOR = "rgba(238,149,150,0.2)";
      };

      config = {
        enableWelcomePage = true;
        prejoinPageEnable = false;
        disableModeratorIndicator = false;
        disableThirdPartyRequests = true;
        defaultLang = "pt-BR";
        enableAuthentication = true;
        authenticationType = "oauth";
        oauth = {
          clientId = "jitsi-meet";
          clientSecret = "7g1PD469rbkp6vFzbx3M5ysVkRUtk5ph8UMsx2jsyp4Rzbrz";
          authUrl = "https://iam.wcbrpar.com/oauth2/authorize";
          tokenUrl = "https://iam.wcbrpar.com/oauth2/token";
          userInfoUrl = "https://iam.wcbrpar.com/oauth2/userinfo";
          scope = "openid profile email";
          userInfoNameField = "name";
        };
      };
      secureDomain.enable = true;

      prosody = {
        lockdown = true;
      };

    };

    # Configuração do Jibri service apenas em pegasus
    jibri = lib.mkIf (config.networking.hostName == "pegasus") {
      enable = true;
      config = {
        recording = {
          recordings-directory = "/var/lib/jitsi-meet/recordings";
        };
        ffmpeg = {
          h264-constant-rate-factor = 21;
        };
        server.port = 8081;
      };
    };

    jitsi-videobridge.openFirewall = lib.mkIf (config.networking.hostName == "pegasus") true;
    
  };

  systemd.tmpfiles.rules = lib.mkIf (config.networking.hostName == "pegasus") [
    "d ${config.services.jibri.config.recording.recordings-directory} 0750 jibri jibri -"
  ];

}

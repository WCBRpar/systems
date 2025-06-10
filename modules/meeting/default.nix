{ config, lib, pkgs, ... }:

{

  services.jitsi-meet = lib.mkIf ( config.networking.hostName == "galactica" ) {
    enable = true;
    hostName = "meet.redcom.digital";
    interfaceConfig = {
      APP_NAME = "meet@redcom.digital";
      DEFAULT_REMOTE_DISPLAY_NAME = "Convidado";
      BRAND_WATERMARK_LINK = "";
      DEFAULT_LOGO_URL = "https://img.redcom.digital/icon.svg" ;
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

    jibri =  lib.mkIf ( config.networking.hostName == "pegasus" ) {
      enable = true; 
    };
    nginx.enable = lib.mkIf ( config.networking.hostName == "pegasus" ) true; 
  };

  services.jibri = lib.mkIf ( config.networking.hostName == "pegasus" ) {
    config = {
      recording = {
	recordings-directory = "/var/lib/jitsi-meet/-recordings";
      };
      ffmpeg = {
        h264-constant-rate-factor = 21;
      };
      server.port = 8081;
    };
  };

  services.jitsi-videobridge.openFirewall = lib.mkIf ( config.networking.hostName == "pegasus" ) true;

  # This is required if the recordings directory can’t be created by Jibri itself
  # e.g. due to missing permissions.
  # If it is under /tmp/ (like the default), this is not needed.
  systemd.tmpfiles.rules = lib.mkIf ( config.networking.hostName == "pegasus" ) [
    "d ${config.services.jibri.config.recording.recordings-directory} 0750 jibri jibri -"
  ];
  
  services.nginx = {
    virtualHosts = {
      "meet.redcom.digital" = lib.mkIf (config.networking.hostName == "galactica") {
	forceSSL = true;
	enableACME = false;
	# useACMEHost = "redcom.digital";
	listen = [ { addr = "0.0.0.0"; port = 8083; } ];
        locations."/" = {
          proxyPass = "http://galactica.wcbrpar.com:80"; # Encaminha para o Traefik
        };

      };
      "meet.wcbrpar.com" = lib.mkIf (config.networking.hostName == "galactica") {
        globalRedirect = "meet.redcom.digital" ;
	forceSSL = false;
        listen = [ { addr = "0.0.0.0"; port = 8083; } ];
      };
    
      # Webserver das Imagens do Jitsi Meet
      "img.redcom.digital" = lib.mkIf (config.networking.hostName == "pegasus") {
        serverAliases = [ "img.wcbrpar.com" ];
        root = "/var/lib/www/shared/images";

	listen = [ { addr = "0.0.0.0"; port = 8081; } ]; 

        # Forçar HTTPS
        forceSSL = true;
        # useACMEHost = "redcom.digital";

	extraConfig = ''
          # Segurança
          # add_header Strict-Transport-Security "max-age=31536000; includeSubdomains; preload" always;
          add_header Referrer-Policy "origin-when-cross-origin" always;
          add_header X-Frame-Options "DENY" always;
          add_header X-Content-Type-Options "nosniff" always;
          
          # Cache
          add_header Cache-Control "public";
        '';

        locations = {
          "= /" = {
            return = "301 https://redcom.digital";
            # Cabeçalhos específicos para o redirecionamento
            extraConfig = ''
              # add_header Cache-Control "no-cache, no-store, must-revalidate";
              # expires 0;
	    '';
          };
          
          "/" = {
            tryFiles = "$uri =404";
            extraConfig = ''
              expires 30d;
              access_log off;
            '';
          };
        };
      };
    };
  };

}

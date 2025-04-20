{ config, lib, pkgs, ... }:

{

  services.jitsi-meet = lib.mkIf ( config.networking.hostName == "galactica" ) {
    enable = true;
    hostName = "meet.redcom.digital";
    interfaceConfig = {
      APP_NAME = "Meet@RED";
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

    jibri = {
      enable = true; 
    };
    caddy.enable = true;
    # nginx.enable = true; 
  };

  services.jibri = lib.mkIf ( config.networking.hostName == "galactica" ) {
    config = {
      recording = {
	recordings-directory = "/var/lib/jitsi-meet/-recordings";
      };
      ffmpeg = {
        h264-constant-rate-factor = 21;
      };
    };
  };

  services.jitsi-videobridge.openFirewall = lib.mkIf ( config.networking.hostName == "galactica" ) true;

  # This is required if the recordings directory can’t be created by Jibri itself
  # e.g. due to missing permissions.
  # If it is under /tmp/ (like the default), this is not needed.
  systemd.tmpfiles.rules = lib.mkIf ( config.networking.hostName == "galactica" ) [
    "d ${config.services.jibri.config.recording.recordings-directory} 0750 jibri jibri -"
  ];
  
  services.caddy.virtualHosts."meet.redcom.digital" = lib.mkIf ( config.networking.hostName == "galactica" ) {
  };

  services.nginx.virtualHosts."meet.wcbrpar.com" = lib.mkIf ( config.networking.hostName == "galactica" ) {
    globalRedirect = "meet.redcom.digital";
    forceSSL = false;
  };

}

{ config, pkgs, ... }:

{

  services.jitsi-meet = {
    enable = true;
    hostName = "meet.redcom.digital";
    interfaceConfig = {
      APP_NAME = "Jitsi Meet";
      AUDIO_LEVEL_PRIMARY_COLOR = "rgba(221,42,42,0.4)";
      AUDIO_LEVEL_SECONDARY_COLOR = "rgba(238,149,150,0.2)";
      DEFAULT_WELCOME_PAGE_LOGO_URL = "images/watermark.svg";
    };

    config = {
      wnableWelcomePage = false;
      prejoinPageEnable = true;
      disableModeratorIndicator = false;
      defaultLang = "pt-BR";
    };
    
    secureDomain.enable = true;

    jibri = {
      enable = true; 
    };
    # caddy.enable = true;
    nginx.enable = true;
  };

  services.jibri = {
    config = {
      recording = {
	recordings-directory = "/var/lib/jitsi-meet/-recordings";
      };
      ffmpeg = {
        h264-constant-rate-factor = 21;
      };
    };
  };

  services.jitsi-videobridge.openFirewall = true;

  # This is required if the recordings directory can’t be created by Jibri itself
  # e.g. due to missing permissions.
  # If it is under /tmp/ (like the default), this is not needed.
  systemd.tmpfiles.rules = [
    "d ${config.services.jibri.config.recording.recordings-directory} 0750 jibri jibri -"
  ];
  
  services.nginx.virtualHosts."meet.redcom.digital" = {
    # enableAcme = true;
    forceSSL = false;
  };

  services.nginx.virtualHosts."meet.wcbrpar.com" = {
    globalRedirect = "meet.redcom.digital";
    forceSSL = false;
  };

}

{ config, pkgs, lib, ... }:

{

  # Nginx webserver
  services.nginx = lib.mkIf ( config.networking.hostName == "galactica" ) {
    virtualHosts = {
      # Servidor de arquivos e imagens estáticas  para as ferramentas hospedadas
      "img.redcom.digital" = {
	serverName = "refcom.digital";
	serverAliases = [ "img.wcbrpar.com" ];
	root =  /var/lib/www/shared/images;

	locations = {

	};
      };
    };
  };

}


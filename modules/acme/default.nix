{ config, pkgs, lib, ... }:

{
  # TLS using ACME
  security.acme = lib.mkIf ( config.networking.hostName != "yashuman" ) {
    acceptTerms = true;
    defaults = {
      email = "gcp-devops@wcbrpar.com";
      renewInterval = "daily";
      keyType = "ec256";
    };

    certs."wcbrpar.com" = {
      email = "devops@wcbrpar.com";
      # Ensure that the web server you use can read the generated certs
      # Take a look at the group option for the web server you choose.
      group = "nginx";
      # Since we have a wildcard vhost to handle port 80,
      # we can generate certs for anything!
      # Just make sure your DNS resolves them.
      extraDomainNames = [ 
        "redcom.digital"
        "walcor.com.br" 
	"wqueiroz.adv.br"
      ];
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      environmentFile = "/var/lib/cloudflare/cloudflare.s";
      dnsPropagationCheck = true;
    };

    # Certificado wildcard para redcom.digital
    certs."redcom.digital" = {
      group = "nginx";
      extraDomainNames = [ "*.redcom.digital" ];
      dnsProvider = "cloudflare";
      environmentFile = "/var/lib/cloudflare/cloudflare.s";
      dnsPropagationCheck = true;
    };

    # Certificado wildcard para walcor.com.br
    certs."walcor.com.br" = {
      group = "nginx";
      extraDomainNames = [ "*.walcor.com.br" ];
      dnsProvider = "cloudflare";
      environmentFile = "/var/lib/cloudflare/cloudflare.s";
    };

    # Certificado wildcard para wqueiroz.adv.br
    certs."wqueiroz.adv.br" = {
      group = "nginx";
      extraDomainNames = [ "*.wqueiroz.adv.br" ];
      dnsProvider = "cloudflare";
      environmentFile = "/var/lib/cloudflare/cloudflare.s";
    };

  };

  # /var/lib/acme/.challenges must be writable by the ACME user
  # and readable by the Nginx user. The easiest way to achieve
  # this is to add the Nginx user to the ACME group.
  users.users.nginx.extraGroups = [ "acme" ];

  # Garante que o diretório de challenges exista
  systemd.tmpfiles.rules = [
    "d /var/lib/acme/.challenges 0755 acme acme -"
  ];

}


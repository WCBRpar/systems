{ config, pkgs, lib, hostName, ... }:

{
  # TLS using ACME
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "gcp-devops@wcbrpar.com";
      renewInterval = "daily";
      keyType = "ec256";
    };

    # certs."wcbrpar.com" = lib.mkIf (config.networking.hostName == "yashuman") {
    #   email = "devops@wcbrpar.com";
    #   # Ensure that the web server you use can read the generated certs
    #   # Take a look at the group option for the web server you choose.
    #   group = "nginx";
    #   # Since we have a wildcard vhost to handle port 80,
    #   # we can generate certs for anything!
    #   # Just make sure your DNS resolves them.
    #   extraDomainNames = [ " *.wcbrpar.com" ]; 
    #   dnsProvider = "cloudflare";
    #   dnsResolver = "1.1.1.1:53";
    #   environmentFile = "/var/lib/cloudflare/cloudflare.s";
    #   dnsPropagationCheck = true;
    # };

    # Certificado wildcard para redcom.digital
    # certs."redcom.digital" = lib.mkIf (config.networking.hostName == "yashuman") {
    #   group = "nginx";
    #   extraDomainNames = [ "*.redcom.digital" ];
    #   dnsProvider = "cloudflare";
    #   environmentFile = "/var/lib/cloudflare/cloudflare.s";
    #   dnsPropagationCheck = true;
    # };

    # Certificado wildcard para walcor.com.br
    # certs."walcor.com.br" = lib.mkIf (config.networking.hostName == "yashuman") {
    #   group = "nginx";
    #   extraDomainNames = [ "*.walcor.com.br" ];
    #   dnsProvider = "cloudflare";
    #   environmentFile = "/var/lib/cloudflare/cloudflare.s";
    # };

    # # Certificado wildcard para wqueiroz.adv.br
    # certs."wqueiroz.adv.br" = lib.mkIf (config.networking.hostName == "yashuman") {
    #   group = "nginx";
    #   extraDomainNames = [ "*.wqueiroz.adv.br" ];
    #   dnsProvider = "cloudflare";
    #   environmentFile = "/var/lib/cloudflare/cloudflare.s";
    # };

  };
  
  # Configuração do traefik-certs-dumper para o Galactica
  # Este serviço monitora o acme.json do Traefik e extrai os certificados para arquivos .pem individuais
  systemd.services.traefik-certs-dumper = lib.mkIf (hostName == "galactica") {
    description = "Dump Traefik certificates from acme.json";
    after = [ "traefik.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      ExecStart = ''
        ${pkgs.traefik-certs-dumper}/bin/traefik-certs-dumper watch \
          --source /var/lib/traefik/acme.json \
          --dest /var/lib/acme \
          --crt-name=fullchain \
          --crt-ext=.pem \
          --key-name=privatekey.pem \
          --key-ext=.pem \
          --domain-subdir=true
      '';
      Restart = "on-failure";
      # O dumper precisa ler o acme.json (propriedade do traefik)
      User = "traefik";
      Group = "traefik";
    };
  };

  # Ajuste de permissões para que outros serviços (como mail) possam ler os certificados
  # Criamos um diretório com permissões de grupo para que postfix/dovecot acessem
  systemd.tmpfiles.rules = lib.mkIf (hostName == "galactica") [
    "d /var/lib/traefik/certs 0755 traefik traefik -"
  
    # Garante que o diretório de challenges exista
    "d /var/lib/acme/.challenges 0755 acme acme -"
  ];

  # /var/lib/acme/.challenges must be writable by the ACME user
  # and readable by the Nginx user. The easiest way to achieve
  # this is to add the Nginx user to the ACME group.
  users.users.nginx.extraGroups = [ "acme" ];

}


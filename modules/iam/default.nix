{ config, lib, pkgs, ... }:

{

  nixpkgs.config.permittedInsecurePackages = [
    "kanidm-1.4.6"
  ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 636 ];
  };

  environment.systemPackages = with pkgs; [ kanidm nginx ];

  services.kanidm = {
    enableClient = true;

    # Configurações do cliente Kanidm (usando objeto Nix)
    clientSettings = {
      uri = "https://iam.wcbrpar.com:8443";
      verify_ca = true;
      verify_hostnames = true;

      # Configurações adicionais (opcional)
      # name = {
      #   uri = "https://alternate.example.com";
      # };
    };

    enableServer = lib.mkIf ( config.networking.hostName == "galactica" ) true;
    serverSettings = lib.mkIf ( config.networking.hostName == "galactica" ) {
      domain = "wcbrpar.com";
      origin = "https://iam.wcbrpar.com";
      bindaddress = "0.0.0.0:8443";
      ldapbindaddress = "0.0.0.0:636";
      tls_chain = "/var/lib/acme/iam.wcbrpar.com/fullchain.pem";
      tls_key = "/var/lib/acme/iam.wcbrpar.com/key.pem";
    };

    unixSettings = {
      hsm_type = "soft";
      default_shell = "/bin/zsh";
      home_attr = "uuid";
      home_prefix = "/home/";
      pam_allowed_login_groups = [ "users" "admins" ];
    };

    enablePam = true;

    provision = lib.mkIf ( config.networking.hostName == "galactica" ) {
      enable = true;
      autoRemove = true;

      groups = {
        "admins" = { };
        "users" = { };
      };

      persons = {
        "wjjunyor" = {
          displayName = "WQJ";
          legalName = "Walter Queiroz Jr";
          mailAddresses = [ "walter@wcbrpar.com" ];
          groups = [ "admins" "users" ];
        };
      };
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."iam.wcbrpar.com" = {
      addSSL = true;
      enableACME = true;
      acmeRoot = null;

      locations."/" = {
        proxyPass = "https://127.0.0.1:8443";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
      locations."/.well-known/acme-challenge" = {
        root = "/var/lib/acme/iam.wcbrpar.com";
      };
    };
  };

  security.acme = {
    certs."iam.wcbrpar.com" = {
      domain = "iam.wcbrpar.com";
      extraDomainNames = [ "ldap.wcbrpar.com" ];
      group = "nginx";
      reloadServices = [ "nginx.service" ];
    };
  };

  users.groups.nginx.members = [ "kanidm" "acme" "nginx" ];
}

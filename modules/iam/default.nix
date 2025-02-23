{ config, lib, pkgs, ... }:

#Thanks to https://ysun.co/kanidm/

let
  inherit (config.security.acme.certs."iam.wcbrpar.com") directory;
in

{
  networking.firewall.allowedTCPPorts = [ 636 ];

  environment.systemPackages = with pkgs; [ kanidm ];

  services.caddy = lib.mkIf (config.networking.hostName == "galactica") {
    enable = true;
    virtualHosts."iam.wcbrpar.com".extraConfig = ''
      import common
      tls "${directory}/fullchain.pem" "${directory}/key.pem"
      reverse_proxy ${config.services.kanidm.provision.instanceUrl} {
          header_up Host {host}
          header_up X-Real-IP {http.request.header.CF-Connecting-IP}
      }
    '';
  };

  services.kanidm = lib.mkIf (config.networking.hostName == "galactica") {
    package = pkgs.kanidm.override { enableSecretProvisioning = true; };

    enableClient = true;
    clientSettings.uri = config.services.kanidm.serverSettings.origin;

    enableServer = true;
    serverSettings = {
      domain = "wcbrpar.com";
      origin = "https://iam.wcbrpar.com";
      trust_x_forward_for = true;

      ldapbindaddress = "0.0.0.0:636";
      bindaddress = "0.0.0.0:8443";

      tls_key = "${directory}/key.pem";
      tls_chain = "${directory}/fullchain.pem";

      log_level = "info";
    };

    provision = {
      enable = true;
      autoRemove = true;

      groups = {
        "admins" = { };
        "users" = { };
      };

      persons = {
        wjjunyor = {
          displayName = "WQJ";
          legalName = "Walter Queiroz Jr";
          mailAddresses = [ "walter@wcbrpar.com" "walter@redcom.digital" "walter@walcor.com.br" ];
          groups = [ "admins" "users" ];
        };
      };
    };
  };

  users.groups.sso.members = [ "caddy" "kanidm" ];
  security.acme.certs."iam.wcbrpar.com" = {
    domain = "wcbrpar.com";
    extraDomainNames = [ "ldap.wcbrpar.com" ];
    group = "sso";
    reloadServices = [ "caddy.service" "kanidm.service" ];
  };
}

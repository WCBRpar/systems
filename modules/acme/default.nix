{ config, pkgs, lib, ... }:

{
  # TLS using ACME
  security.acme = {
    acceptTerms = true;
    defaults.email = "gcp-devops@wcbrpar.com";

    certs."wcbrpar.com" = {
      webroot = "/var/lib/acme/wcbrpar.com";
      email = "gcp-devops@wcbrpar.com";
      # Ensure that the web server you use can read the generated certs
      # Take a look at the group option for the web server you choose.
      group = "nginx";
      # Since we have a wildcard vhost to handle port 80,
      # we can generate certs for anything!
      # Just make sure your DNS resolves them.
      extraDomainNames = [ "redcom.digital" "walcor.com.br" "wqueiroz.adv.br" ];
    };
  };

  # /var/lib/acme/.challenges must be writable by the ACME user
  # and readable by the Nginx user. The easiest way to achieve
  # this is to add the Nginx user to the ACME group.
  users.users.nginx.extraGroups = [ "acme" ];


}


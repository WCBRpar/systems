{ ... }:

{
  # TLS using ACME
  security.acme = {
    acceptTerms = true;
    defaults.email = "gcp-devops@wcbrpar.com";

    certs."iam.wcbrpar.com" = {
      webroot = "/var/lib/acme/iam.wcbrpar.com";
      email = "gcp-devops@wcbrpar.com";
    };
  };

} 

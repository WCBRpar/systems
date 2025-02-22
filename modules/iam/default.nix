{ config, lib, ... }:

{
  
  services.kanidm = lib.mkIf (config.networking.hostName == "galactica") {
  
    enableServer = true;
    enablePam = true;
    serverSettings = {
      domain = "iam.wcbrpar.com";
      tls-chain = /var/lib/acme/iam.wcbrpar.com/chaim.pem; 
      tls-key = /var/lib/acme/iam.wcbrpar.com/key.pem;
   };
 };

  # /var/lib/acme/.chalenges must be readable by 
  # the KanIDM user. The easiest way too achieve:
  # this is to add the KanIDM user to the ACME group. 
  users.users.kanidm.extraGroups = [ "acme" ];

}

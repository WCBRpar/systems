# Naming-scheme - https://namingschemes.com/Battlestar_Galactica
{ 
  galactica = {
    name = "galactica";                     #redundância ?
    id = "13960a97";
    role = "server";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGmT1KuH5xEOsZSyfc61yuf84vEAp2MZwcirOKABv2qe root@galactica";
    ipAddress = {
      internal = "192.168.13.10";
    };
  };

  pegasus = {
    name = "pegasus";
    id = "8bf0dda5";
    role = "server";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKt6p+zn6fJM8n0RcATJ6eylGDk9ojBQaJMznGXAUZJo root@pegasus";
    ipAddress.internal = "192.168.13.20";
  };

  yashuman = {
    name = "yashuman";
    id = "e491eb5c";
    role = "server";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIQ9DhL5m2ofBk0mnAG53h2TGR1s1wxaDTWA+w+bASVJ root@nixos";
    ipAddress.internal = "192.168.13.130";
  };
}

# Naming-scheme - https://namingschemes.com/Battlestar_Galactica
{ 
  galactica = {
    name = "galactica";                     #redundância ?
    id = "13960a97";
    role = "server";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIkanojsZPNIAXC0f4FefYkJjU6W18YhQ6KBzyS5dRhr root@galactica";
    ipAddress = {
      internal = "192.168.13.10";
    };
  };

  pegasus = {
    name = "pegasus";
    id = "8bf0dda5";
    role = "server";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFnkk2zLmLw3DTJpgr6KCJKrWIzVpU4QPbR1MmeQTjMo root@pegasus";
    ipAddress.internal = "192.168.13.20";
  };

  yashuman = {
    name = "yashuman";
    id = "e491eb5c";
    role = "server";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHrk0oi2ofDlVCizvFarzsC4E6xdtP1BAO62mek/5zko root@yashuman";
    ipAddress.internal = "192.168.13.130";
  };
}

let

  root =      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzdmKZQGZOSI1denOeN3kso6Lf/OL92QXN5SHXA7EtG walter@wcbrpar.com";

  wjjunyor =  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzdmKZQGZOSI1denOeN3kso6Lf/OL92QXN5SHXA7EtG walter@wcbrpar.com";

  users =     [ root wjjunyor ];


in

{
  "default.age".publicKeys = users;
  "alternative.age".publicKeys = users;
  "ssh-key.age".publicKeys = users;
  "onlyofficeDocumentServerKey.age".publicKeys = users;
  "odooDatabaseKey.age".publicKeys = users;
}

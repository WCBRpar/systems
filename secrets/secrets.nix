let

  wjjunyor =  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzdmKZQGZOSI1denOeN3kso6Lf/OL92QXN5SHXA7EtG walter@wcbrpar.com";

  users =     [ wjjunyor ];

  galactica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDt3CCZjs0BoMz31szAxs/gBNbZfA+ppjBqDMB8ey7lV root@nixos";

  pegasus =   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZMl3IL3fzhwLirgKiPKEaATdwRKk5ZBYFJw57uCQO4 root@nixos";

  yashuman =  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIQ9DhL5m2ofBk0mnAG53h2TGR1s1wxaDTWA+w+bASVJ root@nixos";

  systems =  [ galactica pegasus yashuman ];

in

{
  "default.age".publicKeys = users ++ systems;
  "alternative.age".publicKeys = users ++ systems;
  "ssh-key.age".publicKeys = systems;
  "onlyofficeDocumentServerKey.age".publicKeys = users ++ systems;
}

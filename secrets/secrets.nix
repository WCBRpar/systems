let

  wjjunyor = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCqsOL2Og5WiY6/4TXuEFMNeJT2BBvGsn/Q72nlsHmkW7upMwqxInxBZC109aLKXVhXowoHV2TlUH8I+dT7IlCsr2YedVVRWWD775kATF46GYir79Ygx/6STOn8NqMX/JvBGPVa3kgAlvbHd7buMAdNDrlaqkNbdZzASyQyGqCT57pAZTaiw/OFXgFjZx5NH0hG+N8ufFDUqTkexLh764aUCuNogPze7p4LHVQ41VFhtysjA6wISKI3ceAORzv1E5Pj4TLisaQ58ghRYV9KFXbtURvNEPHOzjQInk1YctjqcOKpu4YgAstjoG03wdDC9gAy/p8EZAwyHF/O3+UDJyv1 wjjunyor";
  users = [ wjjunyor ];

  galactica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDt3CCZjs0BoMz31szAxs/gBNbZfA+ppjBqDMB8ey7lV";

  pegasus = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZMl3IL3fzhwLirgKiPKEaATdwRKk5ZBYFJw57uCQO4 root@pegasus";

  systems =  [ galactica pegasus ];

in

{
  "default.age".publicKeys = [ users systems ] ;
  "alternative.age".publicKeys = users ++ systems;
  "ssh-key.age".publicKeys = systems;
  "onlyofficeDocumentServerKey.age".publicKeys = users ++ systems;
}

let

  wjjunyor = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDb3I/5wk6V0YxZe0f3dK6AHLcOWXmG8dz2zu7Mbnbq843b1nomr2EVHOHwhTL2r9J/WufjhmuEf3OTFmnpYQNLhYoVisDvTpak4rhXfxX0+3OjvtqF7hOzG6PBmfBwwWaIQc3/Bwrpw3vUdwoa7Or6dPzoWpzAABhy34gydoXa541vsjPajJ971ss7b4qB/SU2cdD9R+vYGNvF7wtD8VOoj6QU7k46oM0ycKhsV8Mku2N42/FP1VZEHZUuoUr0MNaWD/2XB8kOQHSGm/CeXr+IqMj5uzZOzoDN0IqChAlfdCgmQXsH/Ew/5RYLK2N13gWi8wCny5x0VqUY4/758n5BVc5neCnPpKMMB4KEzyKO60PW5sSqLhIynLmDKtW0YJSr7WHDZy8ZoNtevBy2Uhp0bFiGdGCS0JxKsNgf793TNYmgx4+QxpitxpVTyU+Ahul9+pKsWk5cHvECARJ2ik5SqA8I6bMlR0qmZj1hUP4icate3iu75S8lvT3qOWNxjJalAqv/O2JrwyF5pEVD460SyNCREdZ+agpHBWb40psXcQdz384DwbYMXJn3Rb+jxfxS4MDTIwmhYbL2vFjFY6+dt0VkYxg13zHRwlogo9qsuRc8Gh2bW44m8hbPhQW3xbaUX/mlknpVzYmyiT2gupEc5TH5U41zQqhE1xHoWE1xgQ== openpgp:0x4F41A1FF";
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

{ pkgs, ... } :

{

  environment.systemPackages = [ (pkgs.callPackage <agenix/pkgs/agenix.nix> {}) ];

  age.identityPaths = [ "/home/wjjunyor/.ssh/id_ed25519" ];

  age.secrets.default.file = ../../secrets/default.age;
  age.secrets.onlyoffice-nonce = {
    file = ../../secrets/onlyofficeDocumentServerKey.age;
    mode = "770";
    owner = "nginx";
    group = "nginx";
  };
  age.secrets.odoo-databasekey.file = ../../secrets/odooDatabaseKey.age;
}

{ ... } :

{
  age.secrets.default.file = ../../secrets/default.age;
  age.secrets.onlyoffice-nonce  = {
    file = ../../secrets/onlyofficeDocumentServerKey.age;
    mode = "770";
    owner = "nginx";
    group = "nginx";
  };
}

let
  # Chaves SSH existentes - REMOVA UMA DAS DUPLICATAS
  # root e wjjunyor são a MESMA chave, então use apenas uma
  primary = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzdmKZQGZOSI1denOeN3kso6Lf/OL92QXN5SHXA7EtG walter@wcbrpar.com";
  
  # NOVA CHAVE DE DEPLOY
  devops = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICn5PEy7qX9HZ+NkKAFV+CAgydvXe57kmesBdZHja5d7 dev-ops@wcbrpar.com";

  # Combine todas as chaves SEM DUPLICATAS
  allUsers = [ primary devops ];

  # Opcional: crie grupos diferentes para diferentes ambientes
  deployKeys = [ devops ];
  adminKeys = [ primary ];

in
{
  # Versão 2: Segregação de segredos por tipo
  
  "default.age".publicKeys = allUsers;  # Segredos gerais
  "deploy.age".publicKeys = deployKeys; # Segredos específicos para deploy
  
  "alternative.age".publicKeys = allUsers;
  "ssh-key.age".publicKeys = adminKeys;
  "onlyofficeDocumentServerKey.age".publicKeys = allUsers;
  "odooDatabaseKey.age".publicKeys = allUsers;
  "grafanaSecurityKey.age".publicKeys = allUsers;
  "openrouterApiKey.age".publicKeys = allUsers;
}

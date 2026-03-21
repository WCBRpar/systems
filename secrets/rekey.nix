# secrets/rekey.nix
# Configuração do agenix-rekey para re-encryptação automática de secrets
let
  # Importa as configurações de todos os hosts
  hostConfigs = import ../hosts/default.nix;

  # Extrai as chaves públicas de cada host
  hostKeys = builtins.attrValues (builtins.mapAttrs (name: cfg: cfg.sshPublicKey) hostConfigs);

  # Administradores (humanos)
  primary = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzdmKZQGZOSI1denOeN3kso6Lf/OL92QXN5SHXA7EtG walter@wcbrpar.com";
  devops  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICn5PEy7qX9HZ+NkKAFV+CAgydvXe57kmesBdZHja5d7 dev-ops@wcbrpar.com";

  # Chave de deploy (usada apenas no primeiro bootstrap)
  deployKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILbtJ4XG/uKw3e6of+VTuXgC/GCRkO9SKZiXNsuKvJns deploy@bootstrap";

  # Listas úteis
  admins = [ primary devops ];
  all = admins ++ hostKeys;
  hostKeyRecipients = admins ++ [ deployKey ] ++ hostKeys;
in
{
  # Secrets de aplicação
  "default.age".publicKeys = all;
  "deploy.age".publicKeys = all;
  "alternative.age".publicKeys = all;
  "ssh-key.age".publicKeys = admins;
  "onlyofficeDocumentServerKey.age".publicKeys = all;
  "odooDatabaseKey.age".publicKeys = all;
  "grafanaSecurityKey.age".publicKeys = all;
  "openrouterApiKey.age".publicKeys = all;
  "deepseekApiKey.age".publicKeys = all;
  "telegramBotKey.age".publicKeys = all;

  # Secrets das chaves privadas dos hosts
} // builtins.listToAttrs (map (name: {
  name = "host-${name}-key.age";
  value = { publicKeys = hostKeyRecipients; };
}) (builtins.attrNames hostConfigs))

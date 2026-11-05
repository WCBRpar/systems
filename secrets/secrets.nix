# secrets/secrets.nix
let
  # Importa as configurações de todos os hosts
  hostConfigs = import ../hosts/default.nix;

  # Administradores (humanos)
  primary = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzdmKZQGZOSI1denOeN3kso6Lf/OL92QXN5SHXA7EtG walter@wcbrpar.com";
  devops  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICn5PEy7qX9HZ+NkKAFV+CAgydvXe57kmesBdZHja5d7 dev-ops@wcbrpar.com";

  admins = [ primary devops ];
  # Chaves-fonte dos segredos de aplicação: somente identidades administrativas.
  all = admins;
  # Cada host pode recuperar somente a própria chave SSH; admins mantêm a recuperação.
  hostKeyRecipients = name: admins ++ [ hostConfigs.${name}.sshPublicKey ];
in
{
  # Sources de secrets de aplicação (decryptáveis apenas pelos admins)
  "default.age".publicKeys = all;
  "deploy.age".publicKeys = all;
  "alternative.age".publicKeys = all;
  "cloudflareApiKey.age".publicKeys = all;
  "deepseekApiKey.age".publicKeys = all;
  "grafanaSecurityKey.age".publicKeys = all;
  "odooDatabaseKey.age".publicKeys = all;
  "openrouterApiKey.age".publicKeys = all;
  "ssh-key.age".publicKeys = admins;
  "telegramBotKey.age".publicKeys = all;

  # Secrets do Módulo Kanidm 
  "kanidmIdmAdminPassword.age".publicKeys = all; 

  # Secrets do Módulo Office (NextCloud + OnlyOffice)
  "nextcloudAdminPassword.age".publicKeys = all;
  "nextcloudOauthSecret.age".publicKeys = all;
  "onlyofficeJwtSecret.age".publicKeys = all;
  "onlyofficeSecurityNonce.age".publicKeys = all;

  # Secrets do Simple NixOS Mailserver (SNM)
  "ldapMailPassword.age".publicKeys = all;
  "mailWalterPassword.age".publicKeys = all;

  # Secrets das chaves privadas dos hosts
} // builtins.listToAttrs (map (name: {
  name = "host-${name}-key.age";
  value = { publicKeys = hostKeyRecipients name; };
}) (builtins.attrNames hostConfigs))

{ inputs, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.ragenix ];

  # Configure as identidades que o age pode usar
  age.identityPaths = [
    # Chave primária (com senha)
    # "/home/wjjunyor/.ssh/id_ed25519"
    
    # NOVA CHAVE DE DEPLOY (sem senha)
    "/home/wjjunyor/.ssh/id_nixos_deploy"
  ];

  # Configure as permissões do diretório .ssh para garantir acesso
  systemd.tmpfiles.rules = [
    # Garantir que o diretório .ssh existe com permissões corretas
    "d /home/wjjunyor/.ssh 0700 wjjunyor users -"
    # Garantir que a chave de deploy existe e tem permissões corretas
    "f /home/wjjunyor/.ssh/id_nixos_deploy 0600 wjjunyor users -"
  ];

  # Configuração dos segredos
  age.secrets.default.file = ../../secrets/default.age;
  
  age.secrets.onlyoffice-nonce = {
    file = ../../secrets/onlyofficeDocumentServerKey.age;
    mode = "770";
    owner = "nginx";
    group = "nginx";
  };
  
  age.secrets.odoo-databasekey.file = ../../secrets/odooDatabaseKey.age;

  # Script para setup automático da chave de deploy
  system.activationScripts.setup-deploy-key = {
    text = ''
      # Criar a chave de deploy se não existir
      if [ ! -f /home/wjjunyor/.ssh/id_nixos_deploy ] && [ ! -f /home/wjjunyor/.ssh/id_nixos_deploy.pub ]; then
        echo "Generating deploy SSH key..."
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 \
          -f /home/wjjunyor/.ssh/id_nixos_deploy \
          -N "" \
          -C "deploy@$(hostname)"
        echo "Deploy key generated at /home/wjjunyor/.ssh/id_nixos_deploy"
      fi
      
      # Garantir permissões corretas
      chmod 700 /home/wjjunyor/.ssh || true
      chmod 600 /home/wjjunyor/.ssh/id_nixos_deploy 2>/dev/null || true
      chmod 644 /home/wjjunyor/.ssh/id_nixos_deploy.pub 2>/dev/null || true
    '';
    deps = [];
  };
}

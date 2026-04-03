{ config, pkgs, inputs, hostConfig, ... }:

let
  hostConfigs = import ../../hosts/default.nix;
  hostKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
in
{
  environment.systemPackages = [ pkgs.ragenix ];

  # Identidades para descriptografia
  age.identityPaths = [
   #  "/home/wjjunyor/.ssh/id_ed25519"
    "/home/wjjunyor/.ssh/id_nixos_deploy"
  ] ++ hostKeyPaths; # 

  # Configuração dos secrets (movido do networking/default.nix)
  age.secrets."host-ssh-key" = {
    file = ../../secrets/host-${hostConfig.name}-key.age;
    path = "/etc/ssh/ssh_host_ed25519_key";
    owner = "root";
    group = "root";
    mode = "600";
  };

  age.secrets.default.file = ../../secrets/default.age;
  age.secrets.onlyoffice-nonce = {
    file = ../../secrets/onlyofficeDocumentServerKey.age;
    mode = "770";
    owner = "nginx";
    group = "nginx";
  };
  age.secrets.odoo-databasekey.file = ../../secrets/odooDatabaseKey.age;
  age.secrets.grafana-securitykey.file = ../../secrets/grafanaSecurityKey.age;

  # Script bootstrap movido para cá
  systemd.services.ssh-host-key-bootstrap = {
    description = "Generate SSH host public key from private key if missing";
    before = [ "sshd.service" ];
    after = [ "agenix.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = ''
        ${pkgs.bash}/bin/bash -c '
        KEY_PATH="/etc/ssh/ssh_host_ed25519_key"
        PUB_PATH="/etc/ssh/ssh_host_ed25519_key.pub"

        if [ -f "$KEY_PATH" ] && [ ! -f "$PUB_PATH" ]; then
          echo "Generating public key from private key..."
          ${pkgs.openssh}/bin/ssh-keygen -y -f "$KEY_PATH" > "$PUB_PATH"
          chmod 644 "$PUB_PATH"
          echo "Public key generated successfully"
        elif [ -f "$PUB_PATH" ]; then
          echo "Public key already exists, skipping generation"
        else
          echo "WARNING: Private key not found at $KEY_PATH"
          exit 1
        fi
        '
      '';
    };
  };

  # Script de setup da chave de deploy
  system.activationScripts.setup-deploy-key = {
    text = ''
      if [ ! -f /home/wjjunyor/.ssh/id_nixos_deploy ] && [ ! -f /home/wjjunyor/.ssh/id_nixos_deploy.pub ]; then
        echo "Generating deploy SSH key..."
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 \
          -f /home/wjjunyor/.ssh/id_nixos_deploy \
          -N "" \
          -C "deploy@$(hostname)"
        echo "Deploy key generated"
      fi
      chmod 700 /home/wjjunyor/.ssh || true
      chmod 600 /home/wjjunyor/.ssh/id_nixos_deploy 2>/dev/null || true
      chmod 644 /home/wjjunyor/.ssh/id_nixos_deploy.pub 2>/dev/null || true
    '';
    deps = [];
  };
}

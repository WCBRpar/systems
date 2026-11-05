{ config, pkgs, inputs, hostConfig, ... }:

{
  environment.systemPackages = [ pkgs.ragenix ];

  # Host identity used at runtime. It must be available before Agenix decrypts
  # the remaining secrets during activation.
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Keep this identity as a regular file on persistent /etc. A symlink to
  # /run/agenix is broken after reboot and creates a decryption cycle.
  # Initial provisioning/recovery still requires a valid key copied securely.
  age.secrets."host-ssh-key" = {
    file = ../../secrets/host-${hostConfig.name}-key.age;
    path = "/etc/ssh/ssh_host_ed25519_key";
    owner = "root";
    group = "root";
    mode = "0600";
    symlink = false;
  };

  # Encrypted source files are rekeyed per server before deployment.
  age.secrets.default.rekeyFile = ../../secrets/default.age;
  age.secrets.odoo-databasekey.rekeyFile = ../../secrets/odooDatabaseKey.age;

  # This key remains a separate SSH deploy identity, not an age identity.
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

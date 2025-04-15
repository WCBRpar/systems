{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ git libnotify jq ];

  # Configuração do SSH Agent
  programs.ssh = {
    # enable = true;
    startAgent = true;  # Inicia o ssh-agent automaticamente
    extraConfig = ''
      Host github.com
        IdentityFile /root/.ssh/id_ed25519
        IdentitiesOnly yes
        AddKeysToAgent yes  # Adiciona automaticamente ao usar a chave
    '';
  };

  systemd.services.config-autorebuild = {
    description = "Auto-rebuild para NixOS e Home Manager";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      WorkingDirectory = "/etc/nixos";
      ExecStart = pkgs.writeScript "rebuild-enhanced" ''
        #!/bin/sh
        set -euo pipefail
        LOG_FILE="/var/log/auto-rebuild.log"

        # Carrega a chave SSH no agent (nova seção)
        SSH_KEY_LOADED=false
        load_ssh_key() {
          if [ -f "/root/.ssh/id_ed25519" ]; then
            eval "$(ssh-agent -s)" >/dev/null 2>&1
            if ssh-add /root/.ssh/id_ed25519; then
              SSH_KEY_LOADED=true
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] Chave SSH carregada com sucesso" | tee -a "$LOG_FILE"
            else
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: Falha ao carregar chave SSH" | tee -a "$LOG_FILE"
              exit 1
            fi
          fi
        }

        log() {
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
        }

        notify_user() {
          sudo -u wjjunyor DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u wjjunyor)/bus \
          notify-send "Auto Rebuild" "$1"
        }

        # Carrega a chave SSH antes de qualquer operação Git
        load_ssh_key

        NEED_REBUILD=false

        # Resto do seu script original continua aqui...
        # [Seu código existente de verificação de mudanças e rebuild]
      '';
    };
  };

  # Configurações existentes de timer, age.secrets e activationScripts
  systemd.timers.config-autorebuild = {
    description = "Timer para auto-rebuild";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "1h";
    };
  };

  age.secrets."ssh-key" = {
    file = ../../secrets/ssh-key.age;
    path = "/root/.ssh/id_ed25519";
    owner = "root";
    group = "root";
    mode = "600";
  };

  system.activationScripts = {
    setupRootSshDir = ''
      mkdir -p /root/.ssh
      chmod 700 /root/.ssh
    '';
  };
}

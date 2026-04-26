{ config, pkgs, lib, hostName, ... }:
{
  networking.hostName = "REDPAD002";

  imports = [
    ./default.nix
  ];

  # Configurações específicas para nix-on-droid
  # O nix-on-droid roda em ambiente Android/Termux

  # Ferramentas básicas para acesso aos servidores
  environment.systemPackages = with pkgs; [
    # Cliente SSH e ferramentas de rede
    openssh
    mosh              # Mobile Shell - melhor que SSH para conexões móveis
    rsync             # Sincronização de arquivos
    git               # Controle de versão
    wget
    curl

    # Ferramentas de diagnóstico de rede
    nettools
    iperf3
    dnsutils
    traceroute

    # Editores de texto
    vim

    # Terminal multiplexer (essencial para trabalho remoto)
    tmux

    # Ferramentas de segurança
    age               # Criptografia moderna
    gnupg             # GPG para criptografia

    # Utilitários
    htop
    btop
    jq                # Processamento de JSON
    tree
    file
  ];


  # Home-manager para o usuário wjjunyor
  home-manager.users.wjjunyor = { pkgs, ... }: {
    home.stateVersion = "24.11";

    # Pacotes específicos do home
    home.packages = with pkgs; [
      # Ferramentas de desenvolvimento
      gh                 # GitHub CLI

      # Utilitários pessoais
      fzf                # Fuzzy finder
      bat                # Cat com syntax highlighting
      ripgrep            # Grep moderno
      fd                 # Find moderno
    ];

    # Configurações do shell
    programs.bash = {
      enable = true;
      shellAliases = {
        ll = "ls -la";
        la = "ls -A";
        l = "ls -CF";
      };
    };

    # Configuração do Git
    programs.git = {
      enable = true;
      userName = "Walter Queiroz";
      userEmail = "wjjunyor@gmail.com";
    };

    # Configuração do SSH no home
    programs.ssh = {
      enable = true;
      addKeysToAgent = "yes";
    };
  };

  system.stateVersion = "24.11";
}


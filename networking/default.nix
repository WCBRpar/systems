{ config, pkgs, hostConfig, ... }:

let
  # Importa as configurações de todos os hosts
  allHosts = import ../hosts/default.nix;

  # Função para gerar linha do /etc/hosts para um host
  mkHostEntry = hostname: cfg:
    "${cfg.ipAddress.internal} ${hostname}.wcbrpar.com ${hostname}";

  # Gera todas as entradas do /etc/hosts
  hostEntries = builtins.concatStringsSep "\n"
    (builtins.attrValues (builtins.mapAttrs mkHostEntry allHosts));
in
{
  # Configurações básicas do host vindas do hostConfig
  networking = {
    hostName = hostConfig.name;
    hostId = hostConfig.id;

    # Domínio e DNS
    domain = "wcbrpar.com";
    nameservers = [ "84.200.69.80" "84.200.70.40" "1.1.1.1" "8.8.8.8" ];

    # Interface ZeroTier com IP configurado (assumindo /24)
    interfaces.ztc25hlssg = {
      ipv4.addresses = [{
        address = hostConfig.ipAddress.internal;
        prefixLength = 24;   # ajuste se necessário
      }];
    };

    # Firewall
    firewall = {
      enable = true;
      trustedInterfaces = [ "venet0" "ztc25hlssg" ];
    };

    # Hosts estáticos (incluindo todos os servidores)
    extraHosts = ''
      127.0.0.1       localhost
      172.16.129.0    nas.wcbrpar.com
      ${hostEntries}
    '';
  };

  # Known hosts (entradas de /etc/ssh/ssh_known_hosts) para todos os hosts
  programs.ssh.knownHosts = builtins.mapAttrs (hostname: cfg: {
    hostNames = [ hostname "${hostname}.wcbrpar.com" ];
    publicKey = cfg.sshPublicKey;
  }) allHosts;

  # Serviços de rede
  services = {
    avahi = {
      enable = true;
      allowInterfaces = [ "ztc25hlssg" ];
      nssmdns4 = true;
      publish = {
        addresses = true;
        domain = true;
        enable = true;
        userServices = true;
        workstation = true;
      };
    };

    # OpenSSH
    openssh = {
      enable = true;
      openFirewall = true;
      allowSFTP = true;
      settings = {
        AllowUsers = [ "wjjunyor" ];
        PasswordAuthentication = true;
      };
      # Escuta no IP da interface ZeroTier
      listenAddresses = [
        { addr = hostConfig.ipAddress.internal; port = 22; }
        # { addr = "0.0.0.0"; port = 22; } # opcional
      ];
      # Chave de host gerenciada pelo agenix
      hostKeys = [
        { path = "/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
      ];
    };

    # ZeroTier
    zerotierone = {
      enable = true;
      joinNetworks = [ "abfd31bd47447701" ];
    };
  };

  # Utilitários
  programs = {
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  # Instala a chave privada do host via agenix
  age.secrets."host-ssh-key" = {
    file = ../secrets/host-${hostConfig.name}-key.age;
    path = "/etc/ssh/ssh_host_ed25519_key";
    owner = "root";
    group = "root";
    mode = "600";
  };

  # Builds remotas via SSH
  nix.settings.trusted-users = [ "root" "wjjunyor" ];
}

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.host;
  # Função para extrair endereço e prefixo de uma string CIDR (ex: "192.168.1.10/24")
  parseCidr = cidr: let
    parts = splitString "/" cidr;
    addr = elemAt parts 0;
    prefix = toInt (elemAt parts 1);
  in { inherit addr prefix; };
in
{
  options.my.host = {
    name = mkOption {
      type = types.str;
      description = "Hostname";
    };

    id = mkOption {
      type = types.str;
      description = "Host ID (8 hex digits for ZFS, etc.)";
    };

    sshPublicKey = mkOption {
      type = types.str;
      description = "SSH public key of the host (format: 'ssh-ed25519 AAAAC3...')";
    };

    sshPrivateKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to the age-encrypted file containing the host's private SSH key";
    };

    ztc25hlssg = {
      address = mkOption {
        type = types.str;
        example = "192.168.13.130/24";
        description = "IPv4 address in CIDR notation for the ztc25hlssg interface (ZeroTier)";
      };
    };
  };

  config = mkMerge [
    # Configurações básicas do host
    {
      networking.hostName = cfg.name;
      networking.hostId = cfg.id;
    }

    # Configuração da interface ztc25hlssg com o IP fornecido
    {
      networking.interfaces.ztc25hlssg = {
        ipv4.addresses = [
          (let parsed = parseCidr cfg.ztc25hlssg.address; in {
            address = parsed.addr;
            prefixLength = parsed.prefix;
          })
        ];
      };
    }

    # Configuração do SSH para escutar no IP da interface (além de qualquer configuração existente)
    {
      services.openssh = {
        # Não habilitamos o openssh aqui, assumimos que já está habilitado em outro lugar.
        # Apenas adicionamos o listenAddress com mkDefault para não forçar override.
        listenAddresses = mkDefault [
          { addr = (parseCidr cfg.ztc25hlssg.address).addr; port = 22; }
        ];
      };
    }

    # Se um arquivo de chave privada for fornecido, instale-o via agenix
    (mkIf (cfg.sshPrivateKeyFile != null) {
      age.secrets."host-ssh-key" = {
        file = cfg.sshPrivateKeyFile;
        path = "/etc/ssh/ssh_host_ed25519_key";   # local esperado pelo OpenSSH
        owner = "root";
        group = "root";
        mode = "600";
      };

      services.openssh.hostKeys = mkDefault [
        { path = "/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
      ];
    })
  ];
}

{
  description = "Configuração NIXOS dos servidores WCBRpar";

  inputs = {
    # nixpkgs.url = "github:WCBRpar/nixpkgs/WCBRpar/master";
    nixpkgs.url = "path:/nas-data/shared/DEV/nixOS/nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.agenix.follows = "agenix";
    };

    wp4nix = {
      url = "git+https://git.helsinki.tools/helsinki-systems/wp4nix";
      flake = false;
    };

    nixos-home-manager = {
      url = "git+ssh://git@github.com/wjjunyor/nixos-home-manager";
      flake = false;
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Simple NixOS Mailserver
    nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Nix-on-Droid para tablet Android
    nix-on-droid = {
      url = "github:t184256/nix-on-droid/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { self, nixpkgs, home-manager, agenix, agenix-rekey, nixos-hardware, comin, nixos-mailserver, nix-on-droid, ... }@inputs: 
  let
    system = "x86_64-linux";
    hostConfigs = import ./hosts/default.nix;

    # Módulos comuns a todos os sistemas
    commonModules = [
      {
        nixpkgs.config = {
          permittedInsecurePackages = [
            "dotnet-sdk-7.0.410"
            "jitsi-meet-1.0.8043"
            "python3.12-pypdf2-3.0.1"
          ];
          allowUnfree = true;
        };
      }
      # Overlay para pular testes do age
      ({ pkgs, ... }: {
        nixpkgs.overlays = [
          (final: prev: {
            age = prev.age.overrideAttrs (old: {
              doCheck = false;
            });
          })
        ];
      })
      # Adiciona o módulo agenix-rekey
      agenix-rekey.nixosModules.default
      # Configuração do agenix-rekey
      ({ config, pkgs, lib, hostName, ... }: {
        age.rekey = {
          masterIdentities = [
            # Chave privada do administrador principal
            "/home/wjjunyor/.ssh/id_ed25519"
            # Chave privada do host (será instalada pelo agenix)
            "/etc/ssh/ssh_host_ed25519_key"
          ];  

          # Diretório onde as secrets rekeyadas serão armazenadas em cache
          cacheDir = "/var/lib/agenix-rekey";
        };
      })
    ];

    # Função para configurar servidores com Comin
    mkHost = hostname: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs;
        hostConfig = hostConfigs.${hostname};
        hostName = hostname;
      };
      modules = commonModules ++ [
        ./configuration.nix
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
        nixos-mailserver.nixosModules.mailserver
        
        # Configuração do Comin - VERSÃO MÍNIMA E FUNCIONAL
        ({ config, pkgs, lib, hostName, ... }: {
          imports = [ comin.nixosModules.comin ];
          
          # Configuração MÍNIMA do Comin
          services.comin = {
            enable = true;
            
            # Apenas o essencial: remotes com poller
            remotes = [{
              name = "github";
              url = "git@github.com:WCBRpar/systems.git";
              
              # O nome do output do flake (usa o hostname)
              branches.main.name = hostName;
              
              # Poller simples
              poller.period = 60;
            }];
          };

          # Permissões básicas para o comin
          users.users.comin = {
            isSystemUser = true;
            group = "comin";
            home = "/var/lib/comin";
            createHome = true;
          };
          
          users.groups.comin = {};
          users.users.comin.extraGroups = [ "wheel" ];

          # Sudo para nixos-rebuild
          security.sudo.extraRules = [
            {
              users = [ "comin" ];
              commands = [
                {
                  command = "${config.system.path}/bin/nixos-rebuild";
                  options = [ "NOPASSWD" ];
                }
              ];
            }
          ];
        })
        
        # Nix-on-Droid para tablet
        ({ config, pkgs, lib, hostName, ... }: {
          imports = [ nix-on-droid.nixosModules.nix-on-droid ];

          nix-on-droid = {
            enable = true;
            targetUser = "wjjunyor";
          };
        })

      ];
    };

    # Função para workstations
    mkWorkstation = hostname: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs;
        hostName = hostname;
      };
      modules = commonModules ++ [
        ./configuration.nix
        ./workstations/${hostname}.nix
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
        
        # Comin simplificado para workstation
        ({ config, pkgs, lib, hostName, ... }: {
          imports = [ comin.nixosModules.comin ];
          
          services.comin = {
            enable = true;
            remotes = [{
              name = "github";
              url = "https://github.com/WCBRpar/systems.git";
              branches.main.name = hostName;
              poller.period = 60;
            }];
          };
          
          users.users.comin.extraGroups = [ "wheel" ];
          security.sudo.extraRules = [
            {
              users = [ "comin" ];
              commands = [
                {
                  command = "${config.system.path}/bin/nixos-rebuild";
                  options = [ "NOPASSWD" ];
                }
              ];
            }
          ];
        })
      ];
    };

  in {
    nixosConfigurations = {
      galactica = mkHost "galactica";
      pegasus   = mkHost "pegasus";
      yashuman  = mkHost "yashuman";
      t800      = mkWorkstation "t800";
      redpad002 = mkWorkstation "redpad002";
    };
    apps.${system}.agenix-rekey = {
      agenix-rekey = {
        type = "app";
        program = "${agenix-rekey.packages.${system}.default}/bin/agenix-rekey";
      };
    };
  };
}

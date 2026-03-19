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
  };

  outputs = { self, nixpkgs, home-manager, agenix, nixos-hardware, ... }@inputs: 
  let
    system = "x86_64-linux";
    hostConfigs = import ./hosts/default.nix;

    # Módulos comuns a todos os sistemas (servidores e workstations)
    commonModules = [
      {
        nixpkgs.config = {
          permittedInsecurePackages = [
            "dotnet-sdk-7.0.410"
            "jitsi-meet-1.0.8043"
            "kanidm-1.7.4"  
          ];
          allowUnfree = true;
        };
      }
      # Overlay para pular testes do age
      ({ pkgs, ... }: {
        nixpkgs.overlays = [
          (final: prev: {
            age = prev.age.overrideAttrs (old: {
              doCheck = false;  # Desabilita os testes
            });
          })
        ];
      })
    ];

    # Função para configurar servidores (hosts)
    mkHost = hostname: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs;
        hostConfig = hostConfigs.${hostname};    # configuração do host atual
        hostName = hostname;                     # opcional, se precisar do nome
      };
      modules = commonModules ++ [
        ./configuration.nix
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
        # Outros módulos específicos de servidores podem ser adicionados aqui
      ];
    };

    # Função para configurar workstations
    mkWorkstation = hostname: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs;
        # Workstations podem não ter hostConfig, mas se precisar, podemos passar algo similar
        # hostName = hostname;
      };
      modules = commonModules ++ [
        ./configuration.nix
        ./workstations/${hostname}.nix
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
        # Workstations podem ter módulos específicos adicionais
      ];
    };

  in {
    nixosConfigurations = {
      galactica = mkHost "galactica";
      pegasus   = mkHost "pegasus";
      yashuman  = mkHost "yashuman";
      t800      = mkWorkstation "t800";
    };
  };
}

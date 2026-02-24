{
  description = "Configuração NIXOS dos servidores WCBRpar";

  inputs = {
    # nixpkgs.url = "github:WCBRpar/nixpkgs/WCBRpar/master";
    nixpkgs.url = "path:/home/wjjunyor/Shared/DEV/nixOS/nixpkgs";
    
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
  };

  outputs = { self, nixpkgs, home-manager, agenix, ... }@inputs: 
  let
    system = "x86_64-linux";
    
    # Função auxiliar para configurar hosts
    mkHost = hostname: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      
      modules = [
        ./configuration.nix
        ./hosts/${hostname}.nix
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
        
        # Módulo com configurações do nixpkgs
        {
          networking.hostName = hostname;
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
        ({ config, pkgs, ... }: {
          nixpkgs.overlays = [
            (final: prev: {
              age = prev.age.overrideAttrs (old: {
                doCheck = false;  # Desabilita os testes
              });
            })
          ];
        })

      ];
    };
    
  in {
    nixosConfigurations = {
      galactica = mkHost "galactica";
      pegasus   = mkHost "pegasus";
      yashuman  = mkHost "yashuman";
    };
  };
}

{
  description = "NixOS Configuration for Galactica, Pegasus, and Yashuman";

  inputs = {
    agenix.url = "github:ryantm/agenix";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    npins = {
      url = "github:Mic92/npins";
      flake = false; # npins não é um flake
    };
  };

  outputs = {
    self,
    nixpkgs,
    agenix,
    home-manager,
    ...
  } @ inputs: {
    nixosConfigurations = let
      # Configuração base comum a todos os hosts
      baseConfig = {
        imports = [
          ./configuration.nix
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
        ];
      };

      # Função para criar a configuração de cada host
      mkHost = host:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            baseConfig
            (./hosts + "/${host}.nix") # hostName e hostId específicos
          ];
        };
    in {
      galactica = mkHost "galactica";
      pegasus = mkHost "pegasus";
      yashuman = mkHost "yashuman";
    };
  };
}

{
  description = "Configurações NixOS para os hosts WCBRpar";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11"; # Versão estável
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: {
    nixosConfigurations = {
      # Configuração para Galactica
      galactica = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/galactica.nix
          ./configuration.nix
        ];
      };

      # Configuração para Pegasus
      pegasus = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/pegasus.nix
          ./configuration.nix
        ];
      };
    };
  };
}

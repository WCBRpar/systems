{
  description = "NixOS Configuration";

  inputs = {
    agenix.url = "github:ryantm/agenix";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    npins = {
      url = "github:andir/npins";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    lib = nixpkgs.lib;
    mkHost = hostName:
      nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          {
            networking.hostName = lib.mkForce hostName; # Força o hostName primeiro
            _module.check = false; # Temporariamente desativa verificações
          }
          ./configuration.nix
          (./hosts + "/${hostName}.nix")
        ];
      };
  in {
    nixosConfigurations = {
      galactica = mkHost "galactica";
      pegasus = mkHost "pegasus";
      yashuman = mkHost "yashuman";
    };
  };
}

{ config, pkgs, lib, ... }:

{

  # Confugurções do Home-Manager
  home-manager = {
    backupFileExtension = "bkp";
    useGlobalPkgs = true; 
  };

  # WQJ aka wjjunyor home-manager config import
  home-manager.users.wjjunyor = { pkgs, ... }: {
    imports = [
      ./hosts/common.nix
      (./hosts + "/${config.networking.hostName}.nix")

      # (builtins.fetchGit {
      #   url = "git@github.com:wjjunyor/nixos-home-manager.git";
      #   ref = "main";  # Nome do branch
      # } + "/home.nix")  # Especifica o arquivo a ser importado
    ];
  };



}

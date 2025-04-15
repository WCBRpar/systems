{ config, pkgs, lib, ... }:

{

  # Confugurções do Home-Manager
  home-manager.useGlobalPkgs = true; 

  # WQJ aka wjjunyor home-manager config import
  home-manager.users.wjjunyor = { pkgs, ... }: {
    imports = [
      (builtins.fetchGit {
        url = "git@github.com:wjjunyor/nixos-home-manager.git";
        ref = "main";  # Nome do branch
      } + "/home.nix")  # Especifica o arquivo a ser importado
    ];
  };



}

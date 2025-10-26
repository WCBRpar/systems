{ config, pkgs, lib, ... }:


let
  hostname = builtins.readFile /etc/hostname;
in 
{

  # Confugurções do Home-Manager
  home-manager = {
    backupFileExtension = "bkp";
    useGlobalPkgs = true; 
  };

  # WQJ aka wjjunyor home-manager config import
  home-manager.users.wjjunyor = { pkgs, ... }: {
    imports = [
      /home/wjjunyor/.config/home-manager/home.nix
      /home/wjjunyor/.config/home-manager/hosts/common.nix
      (/home/wjjunyor/.config/home-manager/hosts + "/${builtins.replaceStrings ["\n"] [""] hostname}.nix")

      # (builtins.fetchGit {
      #   url = "git@github.com:wjjunyor/nixos-home-manager.git";
      #   ref = "main";  # Nome do branch
      # } + "/home.nix")  # Especifica o arquivo a ser importado
    ];
  };



}

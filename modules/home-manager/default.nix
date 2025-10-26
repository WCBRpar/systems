{ config, pkgs, lib, ... }:

let
  dotfilesDir = ./dotfiles;
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

      ./hosts/common.nix
      (./hosts + "/${config.networking.hostName}.nix")


      # (builtins.fetchGit {
      #   url = "git@github.com:wjjunyor/nixos-home-manager.git";
      #   ref = "main";  # Nome do branch
      # } + "/home.nix")  # Especifica o arquivo a ser importado
    ];
  };

  # Habilitar FUSE e user mounts para o Home Manager
  boot.supportedFilesystem = [ "fuse" "nfs" ];
  security.wrappers.fusermount = {
    source = "${pkgs.fuse}/bin/fusermount";
    owner = "root";
    group = "root";
    setuid = true;
  };

}

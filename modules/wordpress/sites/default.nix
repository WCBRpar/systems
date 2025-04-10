{ config, lib, pkgs, ... }:


{

  imports = 
    [ # Importa os arquivos de cada site na hospedagem

      ## ./sites.nix

      ## ./adf-wp.nix
      ## ./alz-wp.nix
      ## ./brt-wp.nix
      ./ch4-wp.nix
      ## ./grz-wp.nix
      # ./mdn-wp.nix
      ## ./prf-wp.nix
      # ./prs-wp.nix
      ./red-wp.nix
      # ./sbz-wp.nix
      ## ./str-ws.nix
      ## ./ufm-ws.nix
     ];

}

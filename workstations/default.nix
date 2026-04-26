{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../users
    ../modules/home-manager
    ./common.nix
  ];

}

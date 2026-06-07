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
    # imports comuns aos servers e workstations /
    ../users
    ../modules/home-manager
    # imports específicos das workstatios -- /workstations
    ./common.nix
    ./networking
  ];

}

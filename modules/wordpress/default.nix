{ config, lib, pkgs, sources, ... }:


{

  imports = [ ./sites ];

  environment.systemPackages = with pkgs; [ php ];
  environment.variables.WP_VERSION = "6.4";
  

}



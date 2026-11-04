{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  wp4nix = pkgs.callPackage inputs.wp4nix {};

in

{

  imports = [ ./sites ./sites/fix-adf.nix ./sites/fix-cms.nix ./sites/fix-ham.nix ./sites/fix-evm.nix ];

      services.traefik.dynamicConfigOptions = lib.mkIf (config.networking.hostName == "galactica") {
        http = {
          routers = {
            "WP-TMP" = {
              rule = "Host(`adufms.org.br`) || Host(`cutms.org.br`) || Host(`humbertoamaducci.com.br`) || Host(`esperancavermelha.com.br`)";
              service = "wordpress-tmp-server";
              entrypoints = [ "websecure" ];
              tls.certResolver = "cloudflare";
            };
            "WS-TMP" = {
              rule = "Host(`setra.com.br`)";
              service = "website-tmp-server";
              entrypoints = [ "websecure" ];
              tls.certResolver = "cloudflare";
            };
          };
          services = {
            wordpress-tmp-server = {
              loadBalancer = {
                servers = [{ url = "http://pegasus.wcbrpar.com"; }];
                passhostHeader = true;
              };
            };
            website-tmp-server = {
              loadBalancer = {
                servers = [{ url = "http://pegasus.wcbrpar.com:7780"; }];
                passhostHeader = true;
              };
            };
          };
        };
      };

  environment.systemPackages = with pkgs; [ php wp-cli ];
  environment.variables.WP_VERSION = "6.9";

  services.nginx.virtualHosts = {

    "setra.com.br" = {
      listen = [ { addr = "0.0.0.0"; port = 7780; ssl = false; } ];
      root = "/var/lib/www/setra.com.br";
      locations."/" = {
        index = "index.html index.htm";
        tryFiles = "$uri $uri/ =404";
      };
    };
  };

}


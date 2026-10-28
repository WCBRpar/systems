{ lib, hostName, ... }:

let
  hostConfigs = import ../../hosts/default.nix;
  mastodonDomain = "social.redcom.digital";
  mastodonAlias = "s.redcom.digital";
  pegasusZeroTierIP = hostConfigs.pegasus.ipAddress.internal;
  mastodonProxyPort = 8085;
in
{
  # Mastodon, banco, Redis, Sidekiq e Nginx frontal rodam no Pegasus.
  # O módulo NixOS mantém o upstream Mastodon no socket Unix local e o Nginx
  # serve assets e encaminha o streaming/WebSocket.
  # Definir backups externos de PostgreSQL e mídia antes de abrir cadastros.
  services.mastodon = lib.mkIf (hostName == "pegasus") {
    enable = true;
    localDomain = mastodonDomain;
    configureNginx = true;

    # O NixOS module requer ao menos um processo de streaming.
    # Aumentar web/streaming/Sidekiq somente após medir CPU, RAM e fila.
    streamingProcesses = 1;

    # Usa o Postfix local provisionado pelo módulo NixOS por padrão.
    # Confirmar entrega, SPF/DKIM/DMARC e remetente antes de abrir cadastros.
    smtp.fromAddress = "noreply@redcom.digital";
  };

  # O Traefik encaminha apenas pela rede privada ZeroTier. O Nginx do
  # Mastodon não fica exposto em uma interface pública do Pegasus.
  services.nginx.virtualHosts.${mastodonDomain} = lib.mkIf (hostName == "pegasus") {
    listen = [
      {
        addr = pegasusZeroTierIP;
        port = mastodonProxyPort;
        ssl = false;
      }
    ];
    forceSSL = lib.mkForce false;
    enableACME = lib.mkForce false;
  };

  # TLS termina no Traefik central, em Galactica. O nome social.redcom.digital
  # é o único domínio canônico da federação; s.redcom.digital é só um alias web.
  services.traefik.dynamicConfigOptions = lib.mkIf (hostName == "galactica") {
    http = {
      routers = {
        mastodon = {
          rule = "Host(`${mastodonDomain}`)";
          service = "mastodon";
          entrypoints = [ "websecure" ];
          tls.certResolver = "cloudflare";
        };

        mastodon-alias = {
          rule = "Host(`${mastodonAlias}`)";
          service = "noop@internal";
          entrypoints = [ "websecure" ];
          middlewares = [ "mastodon-alias-redirect" ];
          tls.certResolver = "cloudflare";
        };
      };

      middlewares.mastodon-alias-redirect.redirectRegex = {
        regex = "^https?://${mastodonAlias}(.*)$";
        replacement = "https://${mastodonDomain}$1";
        permanent = true;
      };

      services.mastodon.loadBalancer = {
        passHostHeader = true;
        servers = [
          { url = "http://${pegasusZeroTierIP}:${toString mastodonProxyPort}"; }
        ];
      };
    };
  };
}

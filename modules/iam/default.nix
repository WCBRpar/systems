{ config, lib, pkgs, ... }:

let
  # Script para extrair certificados do acme.json do Traefik
  extractCertScript = pkgs.writeShellScriptBin "extract-traefik-certs" ''
    #!/bin/sh
    set -e

    ACME_FILE="/var/lib/traefik/acme.json"
    CERT_DIR="/var/lib/acme/wcbrpar.com"
    DOMAIN="wcbrpar.com"

    # Criar diretório se não existir
    mkdir -p "$CERT_DIR"

    # Verificar se o arquivo acme.json existe
    if [ ! -f "$ACME_FILE" ]; then
      echo "Arquivo $ACME_FILE não encontrado, aguardando certificação inicial..."
      exit 0
    fi

    # Verificar se há certificados para este domínio no provedor cloudflare
    CERT_COUNT=$(${pkgs.jq}/bin/jq -r '.cloudflare.Certificates // [] | length' "$ACME_FILE")

    if [ "$CERT_COUNT" -eq 0 ] || [ "$CERT_COUNT" = "null" ]; then
      echo "Nenhum certificado encontrado no acme.json ainda"
      exit 0
    fi

    # Extrair primeiro certificado válido para o domínio wcbrpar.com
    ${pkgs.jq}/bin/jq -r '
      .cloudflare.Certificates[] |
      select(.Certificate != null and .Key != null) |
      select(.domain.main == "'"$DOMAIN"'" or (.domain.SANs // []) | index("'"$DOMAIN"'")) |
      .Certificate
    ' "$ACME_FILE" | head -1 | \
    ${pkgs.coreutils}/bin/base64 -d > "$CERT_DIR/cert.pem.tmp" || true

    ${pkgs.jq}/bin/jq -r '
      .cloudflare.Certificates[] |
      select(.Certificate != null and .Key != null) |
      select(.domain.main == "'"$DOMAIN"'" or (.domain.SANs // []) | index("'"$DOMAIN"'")) |
      .Key
    ' "$ACME_FILE" | head -1 | \
    ${pkgs.coreutils}/bin/base64 -d > "$CERT_DIR/key.pem.tmp" || true

    # Verificar se os certificados foram extraídos
    if [ ! -s "$CERT_DIR/cert.pem.tmp" ] || [ ! -s "$CERT_DIR/key.pem.tmp" ]; then
      echo "Falha ao extrair certificados"
      rm -f "$CERT_DIR/cert.pem.tmp" "$CERT_DIR/key.pem.tmp"
      exit 0
    fi

    # Mover para arquivos finais
    mv "$CERT_DIR/cert.pem.tmp" "$CERT_DIR/cert.pem"
    mv "$CERT_DIR/key.pem.tmp" "$CERT_DIR/key.pem"

    # Ajustar permissões
    chown kanidm:kanidm "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem"
    chmod 600 "$CERT_DIR/key.pem"
    chmod 644 "$CERT_DIR/cert.pem"

    echo "Certificados extraídos com sucesso para $CERT_DIR"

    # Reiniciar Kanidm para aplicar novos certificados (apenas se o serviço estiver ativo)
    if systemctl is-active --quiet kanidm-server; then
      systemctl restart kanidm-server || true
    fi
  '';
in

{
  networking.firewall = lib.mkIf (config.networking.hostName == "galactica") {
    enable = true;
    allowedTCPPorts = [ 80 443 8443 636 ];
    extraCommands = "";
  };

  environment.systemPackages = with pkgs; [ kanidm_1_9 nginx jq ];

  services.traefik = {
    staticConfigOptions = {
      serversTransports = {
        default = {
          insecureSkipVerify = true;
        };
      };
    };

    dynamicConfigOptions = lib.mkIf (config.networking.hostName == "galactica") {
      http = {
        routers = {
          KN-ALL = {
            rule = "Host(`iam.wcbrpar.com`) || Host(`iam.redcom.digital`)";
            service = "kanidm-service";
            entrypoints = ["websecure"];
            tls = {
              certResolver = "cloudflare";
            };
            middlewares = ["fix-kanidm-headers"];
          };
        };

        services = {
          kanidm-service = {
            loadBalancer = {
              servers = [{ url = "http://127.0.0.1:8443"; }];
              passHostHeader = true;
            };
          };
        };

        middlewares = {
          "fix-kanidm-headers" = {
            headers = {
              customRequestHeaders = {
                X-Forwarded-Proto = "https";
                X-Forwarded-Host = "iam.wcbrpar.com";
                X-Real-IP = "$remote_addr";
              };
              sslRedirect = false;
            };
          };
          "strip-kanidm-prefix" = {
            stripPrefix = {
              prefixes = ["/ui"];
              forceSlash = false;
            };
          };
        };
      };
    };
  };

  services.kanidm = {
    package = pkgs.kanidm_1_9;

    client = {
      enable = true;
      settings = {
        uri = "https://iam.wcbrpar.com";
        verify_ca = false;
        verify_hostnames = false;
      };
    };

    server = lib.mkIf (config.networking.hostName == "galactica") {
      enable = true;
      settings = {
        domain = "wcbrpar.com";
        origin = "https://iam.wcbrpar.com";
        bindaddress = "0.0.0.0:8443";
        ldapbindaddress = "0.0.0.0:636";
        # TLS interno necessário - certificados extraídos do Traefik
        tls_chain = "/var/lib/acme/wcbrpar.com/cert.pem";
        tls_key = "/var/lib/acme/wcbrpar.com/key.pem";
      };
    };

    unix = {
      settings = {
        hsm_type = "soft";
        default_shell = "/bin/zsh";
        home_attr = "uuid";
        home_prefix = "/home/";
        kanidm.pam_allowed_login_groups = [ "users" "admins" ];
        enablePam = lib.mkIf (config.networking.hostName == "galactica") true;
      };
    };

    provision = lib.mkIf (config.networking.hostName == "galactica") {
      enable = true;
      autoRemove = true;

      groups = {
        "admins" = { };
        "users" = { };
      };

      persons = {
        "wjjunyor" = {
          displayName = "WQJ";
          legalName = "Walter Queiroz Jr";
          mailAddresses = [ "walter@wcbrpar.com" ];
          groups = [ "admins" "users" ];
        };
      };
    };
  };

  users.users.kanidm = {
    isSystemUser = true;
    extraGroups = [ "traefik" "acme" "nginx" ];
    group = "kanidm";
  };
  users.groups.kanidm = { };

  # Systemd timer para extrair certificados periodicamente
  systemd.timers."extract-traefik-certs" = lib.mkIf (config.networking.hostName == "galactica") {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "12h";
      Unit = "extract-traefik-certs.service";
    };
  };

  systemd.services."extract-traefik-certs" = lib.mkIf (config.networking.hostName == "galactica") {
    description = "Extrair certificados do Traefik para o Kanidm";
    after = [ "traefik.service" ];
    requires = [ "traefik.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "${extractCertScript}/bin/extract-traefik-certs";
    };
  };

  # Hook para extrair certificados quando o Traefik renovar
  systemd.services."traefik-renew-certs" = lib.mkIf (config.networking.hostName == "galactica") {
    description = "Extrair certificados do Traefik após renovação";
    after = [ "traefik.service" ];
    before = [ "kanidm-server.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "${extractCertScript}/bin/extract-traefik-certs";
    };
  };

  # Garantir que o diretório exista e tenha permissões corretas
  systemd.tmpfiles.rules = [
    "d /var/lib/acme/wcbrpar.com 0755 kanidm kanidm -"
  ];

  # O serviço do Kanidm depende da extração inicial dos certificados
  systemd.services.kanidm-server = lib.mkIf (config.networking.hostName == "galactica") {
    after = [ "traefik.service" "extract-traefik-certs.service" ];
    requires = [ "extract-traefik-certs.service" ];
    wants = [ "extract-traefik-certs.service" ];
  };
}


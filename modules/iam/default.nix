{ config, lib, pkgs, ... }:

let
  # Robust certificate extraction script with auto‑trigger and retry
  extractCertScript = pkgs.writeShellScriptBin "extract-traefik-certs" ''
    #!/bin/sh
    set -e

    ACME_FILE="/var/lib/traefik/acme-wildcard.json"
    CERT_DIR="/var/lib/acme/wcbrpar.com"
    DOMAIN="wcbrpar.com"
    RESOLVER="cloudflare-wildcard"
    TRIGGER_URL="https://iam.wcbrpar.com"
    MAX_RETRIES=60        # up to 10 minutes (60 * 10s)
    SLEEP_SECONDS=10
    TRIGGER_DELAY=20      # wait 20 seconds after triggering before retrying

    mkdir -p "$CERT_DIR"

    # Remove any stale symlinks or empty files
    rm -f "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem"
    # (the directory may still contain other files; we'll overwrite)

    for i in $(seq 1 $MAX_RETRIES); do
      if [ ! -f "$ACME_FILE" ]; then
        echo "Waiting for $ACME_FILE to be created... ($i/$MAX_RETRIES)"
        sleep $SLEEP_SECONDS
        continue
      fi

      # Check if there's a certificate for our wildcard domain
      CERT_COUNT=$(${pkgs.jq}/bin/jq --arg resolver "$RESOLVER" --arg domain "*.$DOMAIN" '
        .[$resolver].Certificates // []
        | map(select(
            .domain.main == $domain or
            ((.domain.SANs // []) | index($domain))
          ))
        | length
      ' "$ACME_FILE" 2>/dev/null || echo 0)

      if [ "$CERT_COUNT" -gt 0 ]; then
        echo "Found certificate for *.$DOMAIN in resolver $RESOLVER"
        break
      fi

      echo "No certificate for *.$DOMAIN yet, attempt $i/$MAX_RETRIES"

      # First few attempts: just wait
      if [ $i -ge 5 ] && [ $((i % 5)) -eq 0 ]; then
        echo "Triggering ACME by hitting $TRIGGER_URL..."
        curl -k -o /dev/null -s -w "%{http_code}\n" "$TRIGGER_URL" || true
        sleep $TRIGGER_DELAY
      else
        sleep $SLEEP_SECONDS
      fi
    done

    # After loop, if still no certificate, exit with error (will be retried by timer)
    if [ "$CERT_COUNT" -eq 0 ]; then
      echo "ERROR: Could not find wildcard certificate after $MAX_RETRIES attempts."
      exit 1
    fi

    # Extract certificate and key
    ${pkgs.jq}/bin/jq --arg resolver "$RESOLVER" --arg domain "*.$DOMAIN" -r '
      .[$resolver].Certificates[]
      | select(
          .domain.main == $domain or
          ((.domain.SANs // []) | index($domain))
        )
      | .Certificate
    ' "$ACME_FILE" > "$CERT_DIR/cert.pem.tmp"

    ${pkgs.jq}/bin/jq --arg resolver "$RESOLVER" --arg domain "*.$DOMAIN" -r '
      .[$resolver].Certificates[]
      | select(
          .domain.main == $domain or
          ((.domain.SANs // []) | index($domain))
        )
      | .Key
    ' "$ACME_FILE" > "$CERT_DIR/key.pem.tmp"

    # Verify both files are non‑empty
    if [ ! -s "$CERT_DIR/cert.pem.tmp" ] || [ ! -s "$CERT_DIR/key.pem.tmp" ]; then
      echo "ERROR: Extracted certificate or key is empty"
      rm -f "$CERT_DIR/cert.pem.tmp" "$CERT_DIR/key.pem.tmp"
      exit 1
    fi

    mv "$CERT_DIR/cert.pem.tmp" "$CERT_DIR/cert.pem"
    mv "$CERT_DIR/key.pem.tmp" "$CERT_DIR/key.pem"

    chown kanidm:kanidm "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem"
    chmod 600 "$CERT_DIR/key.pem"
    chmod 644 "$CERT_DIR/cert.pem"

    echo "Certificates extracted successfully to $CERT_DIR"

    # If Kanidm is running, restart it to pick up new certificates
    if systemctl is-active --quiet kanidm.service; then
      echo "Restarting Kanidm to apply new certificates..."
      systemctl restart kanidm.service || true
    fi
  '';
in
{
  networking.firewall = lib.mkIf (config.networking.hostName == "galactica") {
    enable = true;
    allowedTCPPorts = [ 80 443 8443 636 ];
    extraCommands = "";
  };

  environment.systemPackages = with pkgs; [ kanidm_1_9 nginx jq extractCertScript ];

  services.traefik = {

    dynamicConfigOptions = lib.mkIf (config.networking.hostName == "galactica") {
      http = {
        serversTransports = {
          kanidm-backend = {
            insecureSkipVerify = true;
          };
        };
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
              servers = [{ url = "https://127.0.0.1:8443"; }];
              passHostHeader = true;
              serversTransport = "kanidm-backend";
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
      };
    };

    enablePam = lib.mkIf (config.networking.hostName == "galactica") true;

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

  # Timer to run the extraction script every 12 hours
  systemd.timers."extract-traefik-certs" = lib.mkIf (config.networking.hostName == "galactica") {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "12h";
      Unit = "extract-traefik-certs.service";
    };
  };

  systemd.services."extract-traefik-certs" = lib.mkIf (config.networking.hostName == "galactica") {
    description = "Extract certificates from Traefik for Kanidm";
    after = [ "traefik.service" ];
    requires = [ "traefik.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "${extractCertScript}/bin/extract-traefik-certs";
    };
  };

  # Kanidm will be started by the system; if it fails due to missing certificates,
  # the extraction script will restart it later. No hard dependency.
  # (We keep the service enabled; if it fails, the timer will eventually restart it.)
  systemd.services.kanidm-server = lib.mkIf (config.networking.hostName == "galactica") {
    after = [ "extract-traefik-certs.service" ];
    # Not required, but we ensure that the first extraction runs before Kanidm starts.
    # However, if extraction fails, Kanidm may still start (and fail), but will be restarted later.
  };

  # Clean up old certificate directory on boot
  systemd.tmpfiles.rules = [
    "D /var/lib/acme/wcbrpar.com 0755 kanidm kanidm -"
  ];
}

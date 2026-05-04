{ config, lib, pkgs, hostName, ... }:

let
  # IP do servidor central de logs (galactica)
  lokiServer = "192.168.13.10";

  # Lista de todos os servidores para scraping do Prometheus
  allServers = [
    "192.168.13.10"  # galactica
    "192.168.13.20"  # pegasus
    "192.168.13.130" # yashuman
  ];
in

{
  
  # Cria u usuário Grafana em todas as máquinas
  users = {
    groups.grafana = {};
    users = {
      grafana = {
        isSystemUser = true;
        group = "grafana";
      };
    };
  };

  # Segredos necessários ao módulo Grafana
  age.secrets.grafana-securitykey = {
    file = ../../secrets/grafanaSecurityKey.age;
    owner = "grafana";
    group = "grafana";
    mode = "400";
  };

  services = {

    traefik = lib.mkIf (hostName == "galactica") {
      dynamicConfigOptions = {
        http = {
          routers = {
            GF-ALL = {
              rule = "Host(`grafana.wcbrpar.com`) || Host(`grafana.redcom.digital`) ";
              service = "grafana-service";
              entrypoints = ["websecure"];
              tls = {
                certResolver = "cloudflare";
              };
              # middlewares = ["oidc-grafana"];
            };
          };

          middlewares = {
          };

          services = {
            grafana-service = {
              loadBalancer = {
                servers = [{ url = "http://${toString config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}"; }];
                passHostHeader = true;
              };
            };
            loki-service = {
              loadbalancer = {
                servers = [{ url = "http://${config.services.loki.configuration.server.http_listen_address}:${toString config.services.loki.configuration.server.http_listen_port}"; }];
                passHostHeader = true;
              };
            };
          };
        };
      };
    };

    grafana = lib.mkIf (hostName == "galactica") {
      enable = true;
      settings = {
        server = {
          domain = "grafana.wcbrpar.com";
          http_port = 3000;
          http_addr = "192.168.13.10";
          root_url = "https://grafana.wcbrpar.com/";
        };
        security = {
          # O segredo deve apontar para o PATH do arquivo descriptografado pelo agenix
          secret_key = config.age.secrets.grafana-securitykey.path;
        };

        # Desabilitar autenticação interna do Grafana pois o Grafana já faz isso via OIDC
         auth = {
           disable_login_form = true;
           disable_signout_menu = true;
         };

        # Configuração OIDC Nativa (auth.generic_oauth)
        "auth.generic_oauth" = {
          enabled = true;
          name = "Kanidm";
          client_id = "grafana";
          use_pkce = true;
        
          log_token_payload = true;  # Desativar na conclusão. 
        
          scopes = "openid profile email groups";
          auth_url = "https://iam.wcbrpar.com/ui/oauth2";
          token_url = "https://iam.wcbrpar.com/oauth2/token";
          api_url = "https://iam.wcbrpar.com/oauth2/openid/grafana/userinfo";
        
          # login_attribute_name = "mail_primary";
          login_attribute_path = "preferreed_username"; 
          # email_attribute_name = "mail_primary";
          email_attribute_path = "mail_primary";
          name_attribute_name = "displayname";
          # Mapeamento de Roles (Admin/Editor/Viewer) baseado nos grupos do Kanidm
          role_attribute_path = "contains(groups[*], 'admins@wcbrpar.com') && 'Admin' || contains(groups[*], 'admin-tools@wcbrpar.com') && 'Admin' || 'Viewer'";
          grafana_admin_attribute_path = "contains(groups[*], 'admin-tools@wcbrpar.com')";

          allow_assign_grafana_admin = true;
          oauth_allow_insecure_email_lookup = true;
          force_user_sync = true; 
          allow_sign_up = true;
        };

        # Configurar autenticação proxy para confiar nos headers do Grafana
        "auth.proxy" = {
          enabled = false;
          # header_name = "X-Forwarded-User";
          # header_property = "username";
          # auto_sign_up = true;
          # ldap_sync_ttl = "5m";
        };
      };

      provision = {
        enable = true;

        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              uid = "prometheus";
              url = "http://127.0.0.1:${toString config.services.prometheus.port}";
              access = "proxy";
              isDefault = true;
            }
            {
              name = "Loki";
              type = "loki";
              uid = "loki";
              url = "http://${config.services.loki.configuration.server.http_listen_address}:${toString config.services.loki.configuration.server.http_listen_port}";
              access = "proxy";
              isDefault = false;
            }
          ];
          deleteDatasources = [];
        };

        dashboards.settings.providers = [{
          name = "my dashboards";
          options.path = "/etc/grafana-dashboards";
        }];
      };
    };
    
    # Configuração OAuth2 do Kanidm para o Grafana
    kanidm = lib.mkIf (hostName == "galactica") {
      provision.systems.oauth2 = {
        "grafana" = {
          displayName = "Grafana Monitoring";
          originUrl = [
            "https://grafana.wcbrpar.com/login/generic_oauth"
          ];
          originLanding = "https://grafana.wcbrpar.com";
          imageFile = ../../media-assets/iam-auth-badges/grafana-auth.svg;
          public = true;
          scopeMaps = {
            "admins" = [ "openid" "profile" "email" "groups" ];
            "admin-tools" = [ "openid" "profile" "email" "groups" ];
          };
          # claimMaps = {
          #   "groups" = {
          #     valuesByGroup = {
          #       "admins" = [ "admins@wcbrpar.com" ];
          #       "admin-tools" = [ "admin-tools@wcbrpar.com" ];
          #     };
          #   };
          # };
        };
      };
    };


    # Loki - Servidor central de logs (apenas no galactica)
    loki = lib.mkIf (hostName == "galactica") {
      enable = true;
      configuration = {
        auth_enabled = false;

        server = {
          http_listen_address = "192.168.13.10";
          http_listen_port = 3100;
        };

        common = {
          path_prefix = "/var/lib/loki";
          replication_factor = 1;
        };

        schema_config = {
          configs = [{
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }];
        };

        storage_config = {
          filesystem = {
            directory = "/var/lib/loki/chunks";
          };
          tsdb_shipper = {
            active_index_directory = "/var/lib/loki/tsdb-index";
            cache_location = "/var/lib/loki/tsdb-cache";
          };
        };

        limits_config = {
          retention_period = "744h";
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };

        ingester = {
          lifecycler = {
            ring = {
              kvstore = {
                store = "inmemory";
              };
              replication_factor = 1;
            };
            final_sleep = "0s";
          };
        };

        table_manager = {
          retention_deletes_enabled = false;
          retention_period = "0s";
        };
      };
    };

    # Promtail - Agente de coleta de logs (todos os hosts)
    # promtail = {
    #   enable = false;
    #   configuration = {
    #     server = {
    #       http_listen_address = "0.0.0.0";
    #       http_listen_port = 9080;
    #       grpc_listen_port = 0;
    #     };
    #
    #     clients = [{
    #       url = "http://${lokiServer}:3100/loki/api/v1/push";
    #     }];
    #
    #     positions = {
    #       filename = "/tmp/positions.yaml";
    #     };
    #
    #     scrape_configs = [
    #       {
    #         job_name = "journal";
    #         journal = {
    #           max_age = "12h";
    #           labels = {
    #             job = "systemd-journal";
    #             host = hostName;
    #           };
    #         };
    #         relabel_configs = [
    #           {
    #             source_labels = ["__journal__systemd_unit"];
    #             target_label = "unit";
    #           }
    #           {
    #             source_labels = ["__journal_syslog_identifier"];
    #             target_label = "syslog_identifier";
    #           }
    #         ];
    #       }
    #       {
    #         job_name = "system";
    #         static_configs = [
    #           {
    #             targets = ["localhost"];
    #             labels = {
    #               job = "varlogs";
    #               host = hostName;
    #               __path__ = "/var/log/*log";
    #             };
    #           }
    #         ];
    #       }
    #       {
    #         job_name = "traefik";
    #         static_configs = [
    #           {
    #             targets = ["localhost"];
    #             labels = {
    #               job = "traefik";
    #               host = hostName;
    #               __path__ = "/var/log/traefik/*.log";
    #             };
    #           }
    #         ];
    #       }
    #     ];
    #   };
    # };
    
    # Prometheus: servidor (apenas no galactica) + node exporter (todos os hosts)
    prometheus = lib.mkMerge [
      (lib.mkIf (hostName == "galactica") {
        enable = true;
        port = 9001;
        listenAddress = "0.0.0.0";

        scrapeConfigs = [
          {
            job_name = "prometheus";
            static_configs = [{
              targets = ["localhost:${toString config.services.prometheus.port}"];
              labels = {
                instance = hostName;
              };
            }];
          }
          {
            job_name = "node";
            static_configs = builtins.map (ip: {
              targets = ["${ip}:9100"];
              labels = {
                instance = if ip == "192.168.13.10" then "galactica"
                  else if ip == "192.168.13.20" then "pegasus"
                  else "yashuman";
              };
            }) allServers;
          }
          {
            job_name = "promtail";
            static_configs = builtins.map (ip: {
              targets = ["${ip}:9080"];
              labels = {
                instance = if ip == "192.168.13.10" then "galactica"
                  else if ip == "192.168.13.20" then "pegasus"
                  else "yashuman";
              };
            }) allServers;
          }
        ];
      })

      {
        exporters.node = {
          enable = true;
          port = 9100;
          listenAddress = "0.0.0.0";
          enabledCollectors = [
            "systemd"
            "cpu"
            "diskstats"
            "filesystem"
            "loadavg"
            "meminfo"
            "stat"
            "time"
            "netdev"
          ];
        };
      }
    ];
  };

  # Dashboards do Grafana
  environment.etc = lib.mkIf (hostName == "galactica") {
    "grafana-dashboards/system-metrics.json".text = builtins.toJSON {
      annotations = {
        list = [];
      };
      editable = true;
      fiscalYearStartMonth = 0;
      graphTooltip = 0;
      id = null;
      links = [];
      liveNow = false;
      panels = [
        {
          datasource = { type = "prometheus"; uid = "prometheus"; };
          fieldConfig = {
            defaults = {
              color = { mode = "palette-classic"; };
              custom = {
                axisCenteredZero = false;
                axisColorMode = "text";
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                drawStyle = "line";
                fillOpacity = 10;
                gradientMode = "none";
                hideFrom = { legend = false; tooltip = false; viz = false; };
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = { type = "linear"; };
                showPoints = "auto";
                spanNulls = false;
                stacking = { group = "A"; mode = "none"; };
                thresholdsStepsMode = "normal";
                timeSteps = {};
                tooltip = { mode = "single"; sort = "none"; };
              };
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [{ color = "green"; value = null; } { color = "red"; value = 80; }];
              };
              unit = "percent";
            };
            overrides = [];
          };
          gridPos = { h = 8; w = 12; x = 0; y = 0; };
          id = 1;
          options = {
            legend = { calcs = []; displayMode = "list"; placement = "bottom"; showLegend = true; };
            tooltip = { mode = "single"; sort = "none"; };
          };
          targets = [{
            datasource = { type = "prometheus"; uid = "prometheus"; };
            expr = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
            legendFormat = "{{instance}} - CPU";
            refId = "A";
          }];
          title = "Uso de CPU por Host";
          type = "timeseries";
        }
        {
          datasource = { type = "prometheus"; uid = "prometheus"; };
          fieldConfig = {
            defaults = {
              color = { mode = "palette-classic"; };
              custom = {
                axisCenteredZero = false;
                axisColorMode = "text";
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                drawStyle = "line";
                fillOpacity = 10;
                gradientMode = "none";
                hideFrom = { legend = false; tooltip = false; viz = false; };
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = { type = "linear"; };
                showPoints = "auto";
                spanNulls = false;
                stacking = { group = "A"; mode = "none"; };
                thresholdsStepsMode = "normal";
                timeSteps = {};
                tooltip = { mode = "single"; sort = "none"; };
              };
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [{ color = "green"; value = null; } { color = "red"; value = 80; }];
              };
              unit = "percent";
            };
            overrides = [];
          };
          gridPos = { h = 8; w = 12; x = 12; y = 0; };
          id = 2;
          options = {
            legend = { calcs = []; displayMode = "list"; placement = "bottom"; showLegend = true; };
            tooltip = { mode = "single"; sort = "none"; };
          };
          targets = [{
            datasource = { type = "prometheus"; uid = "prometheus"; };
            expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
            legendFormat = "{{instance}} - Memória";
             refId = "A";
          }];
          title = "Uso de Memória por Host";
          type = "timeseries";
        }
        {
          datasource = { type = "prometheus"; uid = "prometheus"; };
          fieldConfig = {
            defaults = {
              color = { mode = "palette-classic"; };
              custom = {
                axisCenteredZero = false;
                axisColorMode = "text";
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                drawStyle = "line";
                fillOpacity = 10;
                gradientMode = "none";
                hideFrom = { legend = false; tooltip = false; viz = false; };
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = { type = "linear"; };
                showPoints = "auto";
                spanNulls = false;
                stacking = { group = "A"; mode = "none"; };
                thresholdsStepsMode = "normal";
                timeSteps = {};
                tooltip = { mode = "single"; sort = "none"; };
              };
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [{ color = "green"; value = null; } { color = "yellow"; value = 70; } { color = "red"; value = 90; }];
              };
              unit = "percent";
            };
            overrides = [];
          };
          gridPos = { h = 8; w = 12; x = 0; y = 8; };
          id = 3;
          options = {
            legend = { calcs = []; displayMode = "list"; placement = "bottom"; showLegend = true; };
            tooltip = { mode = "single"; sort = "none"; };
          };
          targets = [{
            datasource = { type = "prometheus"; uid = "prometheus"; };
            expr = "100 - ((node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}) * 100)";
            legendFormat = "{{instance}} - Disco";
            refId = "A";
          }];
          title = "Uso de Disco (/) por Host";
          type = "timeseries";
        }
        {
          datasource = { type = "prometheus"; uid = "prometheus"; };
          fieldConfig = {
            defaults = {
              color = { mode = "thresholds"; };
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [{ color = "green"; value = null; } { color = "yellow"; value = 1; } { color = "red"; value = 5; }];
              };
            };
            overrides = [];
          };
          gridPos = { h = 8; w = 12; x = 12; y = 8; };
          id = 4;
          options = {
            colorMode = "value";
            graphMode = "area";
            justifyMode = "auto";
            orientation = "auto";
            reduceOptions = { calcs = ["lastNotNull"]; fields = ""; values = false; };
            textMode = "auto";
          };
          targets = [{
            datasource = { type = "prometheus"; uid = "prometheus"; };
            expr = "node_load1";
            legendFormat = "{{instance}}";
            refId = "A";
          }];
          title = "Load Average (1m)";
          type = "stat";
        }
      ];
      refresh = "5s";
      schemaVersion = 38;
      style = "dark";
      tags = ["system" "nixos"];
      templating = { list = []; };
      time = { from = "now-1h"; to = "now"; };
      timepicker = {};
      timezone = "browser";
      title = "System Metrics - All Hosts";
      uid = "system-metrics-all";
      version = 1;
      weekStart = "";
    };
    
    # Dashboard de logs centralizados
    "grafana-dashboards/centralized-logs.json".text = builtins.toJSON {
      annotations = {
        list = [];
      };
      editable = true;
      fiscalYearStartMonth = 0;
      graphTooltip = 0;
      id = null;
      links = [];
      liveNow = false;
      panels = [
        {
          datasource = { type = "loki"; uid = "loki"; };
          gridPos = { h = 25; w = 24; x = 0; y = 0; };
          id = 1;
          options = {
            dedupStrategy = "none";
            enableLogDetails = true;
            preWrapLines = true;
            showLabels = true;
            showTime = true;
            sortOrder = "Descending";
            wrapLogMessage = false;
          };
          targets = [{
            datasource = { type = "loki"; uid = "loki"; };
            expr = "{host=~\"$host\", job=~\"$job\"}";
            queryType = "range";
            refId = "A";
          }];
          title = "Logs Centralizados";
          type = "table";
        }
      ];
      refresh = "5s";
      schemaVersion = 38;
      style = "dark";
      tags = ["logs" "loki"];
      templating = {
        list = [
          {
            current = { selected = true; text = "All"; value = "$__all"; };
            datasource = { type = "loki"; uid = "loki"; };
            definition = "label_values(host)";
            hide = 0;
            includeAll = true;
            label = "Host";
            multi = true;
            name = "host";
            options = [];
            query = "label_values(host)";
            refresh = 1;
            regex = "";
            skipUrlSync = false;
            sort = 0;
            type = "query";
          }
          {
            current = { selected = true; text = "All"; value = "$__all"; };
            datasource = { type = "loki"; uid = "loki"; };
            definition = "label_values(job)";
            hide = 0;
            includeAll = true;
            label = "Job";
            multi = true;
            name = "job";
            options = [];
            query = "label_values(job)";
            refresh = 1;
            regex = "";
            skipUrlSync = false;
            sort = 0;
            type = "query";
          }
        ];
      };
      time = { from = "now-1h"; to = "now"; };
      timepicker = {};
      timezone = "browser";
      title = "Centralized Logs";
      uid = "centralized-logs";
      version = 1;
      weekStart = "";
    };

    # NOVO DASHBOARD: All Systems (métricas + rede + logs)
    "grafana-dashboards/all-systems.json".text = builtins.toJSON {
      annotations = {
        list = [
          {
            builtIn = 1;
            datasource = {
              type = "grafana";
              uid = "-- Grafana --";
            };
            enable = true;
            hide = true;
            iconColor = "rgba(0, 211, 255, 1)";
            name = "Annotations & Alerts";
            type = "dashboard";
          }
        ];
      };
      editable = true;
      fiscalYearStartMonth = 0;
      graphTooltip = 0;
      links = [];
      panels = [
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          fieldConfig = {
            defaults = {
              color = {
                mode = "palette-classic";
              };
              custom = {
                axisBorderShow = false;
                axisCenteredZero = false;
                axisColorMode = "text";
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                barWidthFactor = 0.6;
                drawStyle = "line";
                fillOpacity = 10;
                gradientMode = "none";
                hideFrom = {
                  legend = false;
                  tooltip = false;
                  viz = false;
                };
                insertNulls = false;
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = {
                  type = "linear";
                };
                showPoints = "auto";
                showValues = false;
                spanNulls = false;
                stacking = {
                  group = "A";
                  mode = "none";
                };
                thresholdsStyle = {
                  mode = "off";
                };
              };
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = 0;
                  }
                  {
                    color = "red";
                    value = 80;
                  }
                ];
              };
              unit = "percent";
            };
            overrides = [];
          };
          gridPos = {
            h = 8;
            w = 12;
            x = 0;
            y = 0;
          };
          id = 1;
          options = {
            legend = {
              calcs = [];
              displayMode = "list";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              hideZeros = false;
              mode = "single";
              sort = "none";
            };
          };
          pluginVersion = "12.4.2";
          targets = [
            {
              expr = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
              legendFormat = "{{instance}}";
              refId = "A";
            }
          ];
          title = "Uso de CPU por Host";
          type = "timeseries";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          fieldConfig = {
            defaults = {
              color = {
                mode = "palette-classic";
              };
              custom = {
                axisBorderShow = false;
                axisCenteredZero = false;
                axisColorMode = "text";
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                barWidthFactor = 0.6;
                drawStyle = "line";
                fillOpacity = 10;
                gradientMode = "none";
                hideFrom = {
                  legend = false;
                  tooltip = false;
                  viz = false;
                };
                insertNulls = false;
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = {
                  type = "linear";
                };
                showPoints = "auto";
                showValues = false;
                spanNulls = false;
                stacking = {
                  group = "A";
                  mode = "none";
                };
                thresholdsStyle = {
                  mode = "off";
                };
              };
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = 0;
                  }
                  {
                    color = "red";
                    value = 80;
                  }
                ];
              };
              unit = "percent";
            };
            overrides = [];
          };
          gridPos = {
            h = 8;
            w = 12;
            x = 12;
            y = 0;
          };
          id = 2;
          options = {
            legend = {
              calcs = [];
              displayMode = "list";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              hideZeros = false;
              mode = "single";
              sort = "none";
            };
          };
          pluginVersion = "12.4.2";
          targets = [
            {
              expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
              legendFormat = "{{instance}}";
              refId = "A";
            }
          ];
          title = "Uso de Memória por Host";
          type = "timeseries";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          fieldConfig = {
            defaults = {
              color = {
                mode = "palette-classic";
              };
              custom = {
                axisBorderShow = false;
                axisCenteredZero = false;
                axisColorMode = "text";
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                barWidthFactor = 0.6;
                drawStyle = "line";
                fillOpacity = 10;
                gradientMode = "none";
                hideFrom = {
                  legend = false;
                  tooltip = false;
                  viz = false;
                };
                insertNulls = false;
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = {
                  type = "linear";
                };
                showPoints = "auto";
                showValues = false;
                spanNulls = false;
                stacking = {
                  group = "A";
                  mode = "none";
                };
                thresholdsStyle = {
                  mode = "off";
                };
              };
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = 0;
                  }
                  {
                    color = "yellow";
                    value = 70;
                  }
                  {
                    color = "red";
                    value = 90;
                  }
                ];
              };
              unit = "percent";
            };
            overrides = [];
          };
          gridPos = {
            h = 8;
            w = 12;
            x = 0;
            y = 8;
          };
          id = 3;
          options = {
            legend = {
              calcs = [];
              displayMode = "list";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              hideZeros = false;
              mode = "single";
              sort = "none";
            };
          };
          pluginVersion = "12.4.2";
          targets = [
            {
              expr = "100 - ((node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}) * 100)";
              legendFormat = "{{instance}}";
              refId = "A";
            }
          ];
          title = "Uso de Disco (/)";
          type = "timeseries";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          fieldConfig = {
            defaults = {
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = 0;
                  }
                  {
                    color = "yellow";
                    value = 1;
                  }
                  {
                    color = "red";
                    value = 5;
                  }
                ];
              };
            };
            overrides = [];
          };
          gridPos = {
            h = 8;
            w = 12;
            x = 12;
            y = 8;
          };
          id = 4;
          options = {
            colorMode = "value";
            graphMode = "area";
            justifyMode = "auto";
            orientation = "auto";
            percentChangeColorMode = "standard";
            reduceOptions = {
              calcs = ["lastNotNull"];
              fields = "";
              values = false;
            };
            showPercentChange = false;
            textMode = "auto";
            wideLayout = true;
          };
          pluginVersion = "12.4.2";
          targets = [
            {
              expr = "node_load1";
              legendFormat = "{{instance}}";
              refId = "A";
            }
          ];
          title = "Load Average (1m)";
          type = "stat";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          fieldConfig = {
            defaults = {
              color = {
                mode = "palette-classic";
              };
              custom = {
                axisBorderShow = false;
                axisCenteredZero = false;
                axisColorMode = "text";
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                barWidthFactor = 0.6;
                drawStyle = "lines";
                fillOpacity = 10;
                gradientMode = "none";
                hideFrom = {
                  legend = false;
                  tooltip = false;
                  viz = false;
                };
                insertNulls = false;
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = {
                  type = "linear";
                };
                showPoints = "auto";
                showValues = false;
                spanNulls = false;
                stacking = {
                  group = "A";
                  mode = "none";
                };
                thresholdsStyle = {
                  mode = "off";
                };
              };
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = 0;
                  }
                  {
                    color = "red";
                    value = 80;
                  }
                ];
              };
              unit = "Bps";
            };
            overrides = [];
          };
          gridPos = {
            h = 8;
            w = 12;
            x = 0;
            y = 16;
          };
          id = 5;
          options = {
            legend = {
              calcs = [];
              displayMode = "list";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              hideZeros = false;
              mode = "single";
              sort = "none";
            };
          };
          pluginVersion = "12.4.2";
          targets = [
            {
              expr = "rate(node_network_receive_bytes_total{instance=~\"$host\", device!=\"lo\"}[5m])";
              legendFormat = "{{instance}} - {{device}} RX";
              refId = "A";
            }
            {
              expr = "rate(node_network_transmit_bytes_total{instance=~\"$host\", device!=\"lo\"}[5m])";
              legendFormat = "{{instance}} - {{device}} TX";
              refId = "B";
            }
          ];
          title = "Tráfego de Rede (bytes/s)";
          type = "timeseries";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          fieldConfig = {
            defaults = {
              color = {
                mode = "palette-classic";
              };
              custom = {
                axisBorderShow = false;
                axisCenteredZero = false;
                axisColorMode = "text";
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                barWidthFactor = 0.6;
                drawStyle = "lines";
                fillOpacity = 10;
                gradientMode = "none";
                hideFrom = {
                  legend = false;
                  tooltip = false;
                  viz = false;
                };
                insertNulls = false;
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = {
                  type = "linear";
                };
                showPoints = "auto";
                showValues = false;
                spanNulls = false;
                stacking = {
                  group = "A";
                  mode = "none";
                };
                thresholdsStyle = {
                  mode = "off";
                };
              };
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = 0;
                  }
                  {
                    color = "red";
                    value = 80;
                  }
                ];
              };
              unit = "cps";
            };
            overrides = [];
          };
          gridPos = {
            h = 8;
            w = 12;
            x = 12;
            y = 16;
          };
          id = 6;
          options = {
            legend = {
              calcs = [];
              displayMode = "list";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              hideZeros = false;
              mode = "single";
              sort = "none";
            };
          };
          pluginVersion = "12.4.2";
          targets = [
            {
              expr = "rate(node_network_receive_errs_total{instance=~\"$host\", device!=\"lo\"}[5m])";
              legendFormat = "{{instance}} - {{device}} RX errors";
              refId = "A";
            }
            {
              expr = "rate(node_network_transmit_errs_total{instance=~\"$host\", device!=\"lo\"}[5m])";
              legendFormat = "{{instance}} - {{device}} TX errors";
              refId = "B";
            }
          ];
          title = "Erros de Rede (pacotes/s)";
          type = "timeseries";
        }
        {
          datasource = {
            type = "loki";
            uid = "loki";
          };
          fieldConfig = {
            defaults = {};
            overrides = [];
          };
          gridPos = {
            h = 20;
            w = 24;
            x = 0;
            y = 24;
          };
          id = 7;
          options = {
            dedupStrategy = "none";
            enableInfiniteScrolling = false;
            enableLogDetails = true;
            preWrapLines = true;
            showControls = false;
            showLabels = true;
            showTime = true;
            sortOrder = "Descending";
            unwrappedColumns = false;
            wrapLogMessage = true;
          };
          pluginVersion = "12.4.2";
          targets = [
            {
              direction = "backward";
              editorMode = "builder";
              expr = "{host=~\"$host\", job=~\"$job\"} |~ \"$level_filter\"";
              queryType = "range";
              refId = "A";
            }
          ];
          title = "Logs Centralizados";
          type = "logs";
        }
      ];
      preload = false;
      refresh = "5s";
      schemaVersion = 42;
      tags = [
        "system"
        "logs"
        "network"
        "nixos"
      ];
      templating = {
        list = [
          {
            current = {
              text = "All";
              value = "$__all";
            };
            datasource = {
              type = "prometheus";
              uid = "prometheus";
            };
            includeAll = true;
            label = "Host";
            multi = true;
            name = "host";
            options = [];
            query = "label_values(node_uname_info, instance)";
            refresh = 1;
            regexApplyTo = "value";
            type = "query";
          }
          {
            current = {
              text = "All";
              value = "$__all";
            };
            datasource = {
              type = "loki";
              uid = "loki";
            };
            includeAll = true;
            label = "Job";
            multi = true;
            name = "job";
            options = [];
            query = "label_values(job)";
            refresh = 1;
            regexApplyTo = "value";
            type = "query";
          }
          {
            current = {
              text = "";
              value = "";
            };
            hide = 0;
            label = "Error Level Filter";
            name = "level_filter";
            options = [];
            query = "";
            type = "textbox";
          }
        ];
      };
      time = {
        from = "now-1h";
        to = "now";
      };
      timepicker = {};
      timezone = "browser";
      title = "All Systems";
      uid = "all-systems";
      version = 1;
      weekStart = "";
    };
  };

  # Firewall - liberar portas do monitoramento
  networking.firewall = {
    allowedTCPPorts = [
      3000  # Grafana
      3100  # Loki
      9001  # Prometheus
      9080  # Promtail
      9100  # Node Exporter
    ];
  };
}

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

  services = {

    traefik = lib.mkIf ( hostName == "galactica" ) {

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
            };
            LOKI-ROUTER = {
              rule = "Host(`loki.wcbrpar.com`)";
              service = "loki-service";
              entrypoints = ["websecure"];
              tls = {
                certResolver = "cloudflare";
              };
            };
          };
          services = {
            grafana-service = {
              loadbalancer = {
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

    grafana = lib.mkIf ( hostName == "galactica" ) {
      # declarativePlugins = with pkgs.grafanaPlugins; [ ... ];

      enable = true;
      settings = { 
        server = { 
          domain = "grafana.wcbrpar.com";
          http_port = 3000;
          http_addr = "192.168.13.10";
        };
        security = {
          secret_key = config.age.secrets.grafana-securitykey.path; 
         };
      };

      provision = {
        enable = true;

        dashboards.settings.providers = [{
          name = "my dashboards";
          options.path = "/etc/grafana-dashboards";
        }];

        datasources.settings.datasources = [
          # "Built-in" datasources can be provisioned - c.f. https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
            isDefault = true;
          }
          # Loki datasource para logs centralizados
          {
            name = "Loki";
            type = "loki";
            url = "http://${config.services.loki.configuration.server.http_listen_address}:${toString config.services.loki.configuration.server.http_listen_port}";
            isDefault = false;
          }
          # Some plugins also can - c.f. https://grafana.com/docs/plugins/yesoreyeram-infinity-datasource/latest/setup/provisioning/
          {
            name = "Infinity";
            type = "yesoreyeram-infinity-datasource";
          }
          # But not all - c.f. https://github.com/fr-ser/grafana-sqlite-datasource/issues/141
        ];

        # Note: removing attributes from the above `datasources.settings.datasources` is not enough for them to be deleted on `grafana`;
        # One needs to use the following option:
        # datasources.settings.deleteDatasources = [ { name = "foo"; orgId = 1; } { name = "bar"; orgId = 1; } ];
      };
    };

    # Loki - Servidor central de logs (apenas no galactica)
    loki = lib.mkIf ( hostName == "galactica" ) {
      enable = true;
      configuration = {
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
          retention_period = "744h"; # 31 dias
          enforce_metric_name = false;
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };
        
        chunk_store_config = {
          max_look_back_period = "0s";
        };
        
        table_manager = {
          retention_deletes_enabled = false;
          retention_period = "0s";
        };
      };
    };

    # Promtail - Agente de coleta de logs (todos os hosts)
    promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };
        
        clients = [{
          url = "http://${lokiServer}:3100/loki/api/v1/push";
        }];
        
        positions = {
          filename = "/tmp/positions.yaml";
        };
        
        scrape_configs = [
          # Logs do sistema (journalctl)
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = hostName;
              };
            };
            relabel_configs = [
              {
                source_labels = ["__journal__systemd_unit"];
                target_label = "unit";
              }
              {
                source_labels = ["__journal_syslog_identifier"];
                target_label = "syslog_identifier";
              }
            ];
          }
          
          # Logs de arquivos específicos
          {
            job_name = "system";
            static_configs = [
              {
                targets = ["localhost"];
                labels = {
                  job = "varlogs";
                  host = hostName;
                  __path__ = "/var/log/*log";
                };
              }
            ];
          }
          
          # Logs do Nginx/Traefik se disponíveis
          {
            job_name = "traefik";
            static_configs = [
              {
                targets = ["localhost"];
                labels = {
                  job = "traefik";
                  host = hostName;
                  __path__ = "/var/log/traefik/*.log";
                };
              }
            ];
          }
        ];
      };
    };

    prometheus = {
      enable = true;
      port = 9001;
      listenAddress = "0.0.0.0";
      
      # Configuração para scrapear métricas de todos os hosts
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
        
        # Node Exporter - Métricas do sistema de todos os hosts
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
        
        # Promtail - Métricas dos agentes de log
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
    };
    
    # Node Exporter - Exporta métricas do sistema (todos os hosts)
    prometheus.exporters.node = {
      enable = true;
      port = 9100;
      enabledCollectors = [
        "systemd"
        "network"
        "cpu"
        "diskstats"
        "filesystem"
        "loadavg"
        "meminfo"
        "stat"
        "time"
      ];
    };

  };

  # Dashboards do Grafana
  environment.etc = lib.mkIf ( hostName == "galactica" ) {
    # Dashboard de métricas do sistema
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

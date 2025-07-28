{ config, lib, ... }:

{

  services = {

    traefik = lib.mkIf ( config.networking.hostName == "galactica" ) {

      dynamicConfigOptions = {
        http = {
	        routers = {
	          grafana = {
	            rule = "Host(`grafana.wcbrpar.com`)";
	            service = "grafana-service";
	            entrypoints = ["websecure"];
	            tls = {
		            certResolver = "cloudflare";
	            };
	          };
	        };
	        services = {
	          grafana-service = {
	            loadbalancer = {
	              servers = [{ url = "http://${toString config.services.grafana.addr}:${toString config.services.grafana.port}"; }];
		            passHostHeader = true;
              };
	          };
	        };
	      };
      };
    };

    grafana = lib.mkIf ( config.networking.hostName == "galactica" ) {
      # declarativePlugins = with pkgs.grafanaPlugins; [ ... ];

      enable = true;
      domain = "grafana.wcbrpar.com";
      port = 3000;
      addr = "192.168.13.10";

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

    prometheus = {
      enable = true;
      port = 9001;
    };
  };

  # environment.etc = {
  #   grafana = {
  #     source = ./. + "/grafana-dashboards/some-dashboard.json";
  #     group = "grafana";
  #     user = "grafana";
  #   };
  # };

}

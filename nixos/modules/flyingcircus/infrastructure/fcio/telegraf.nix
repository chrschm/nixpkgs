{ config, pkgs, lib, ... }:
with lib;

let
  fclib = import ../../lib;
  enc = config.flyingcircus.enc;
  params = if enc ? parameters then enc.parameters else {};
  labels = if enc ? labels then enc.labels else [];

  port = "9126";

  encTags =
    builtins.listToAttrs
      (builtins.filter
        # Filter unwanted labels. Some are multi-valued, which does not make
        # sense for prometheus. The "env" might change, hence move metrics to
        # another time series. If the user creates custom labels this will
        # happen as well. But that's the user's choice then.
        (tag: ((tag.name != "fc_component") &&
               (tag.name != "fc_role") &&
               (tag.name != "env")))
        (map
          (split: nameValuePair (elemAt split 0) (elemAt split 1))
            (map (combined: splitString ":" combined) labels)));

    globalTags = encTags // {
      resource_group = params.resource_group;
    };

in
mkIf (params ? location && params ? resource_group) {

  services.telegraf.enable = true;
  services.telegraf.configDir =
    if builtins.pathExists "/etc/local/telegraf"
    then /etc/local/telegraf
    else null;
  services.telegraf.extraConfig = {
    global_tags = globalTags;
    outputs = {
      prometheus_client = [{
        listen = "${lib.head(
          fclib.listenAddressesQuotedV6 config "ethsrv")}:${port}";
      }];
    };
  };
  services.telegraf.inputs = {
    cpu = [{
      percpu = false;
      totalcpu = true;
    }];
    disk = [{
      mount_points = [
        "/"
        "/tmp"
      ];
    }];
    diskio = [{
      skip_serial_number = true;
    }];
    kernel = [{}];
    mem = [{}];
    netstat = [{}];
    net = [{}];
    processes = [{}];
    system = [{}];
    swap = [{}];
  };

  systemd.services.telegraf.serviceConfig = {
    PermissionsStartOnly = "true";
    ExecStartPre = ''
      ${pkgs.coreutils}/bin/install -d -o root -g service -m 02775 \
        /etc/local/telegraf
    '';
  };

  environment.etc."local/telegraf/README.txt".text = ''
    There is a telegraf daemon running on this machine to gather statistics.
    To gather additional or custom statistis add a proper configuration file
    here. `*.conf` will beloaded.

    See https://github.com/influxdata/telegraf/blob/master/docs/CONFIGURATION.md
    for details on how to configure telegraf.
  '';

  flyingcircus.services.sensu-client.checks = {
    telegraph_prometheus_output = {
      notification = "Telegraf prometheus output alive";
      command = ''
        check_http -v -j HEAD -H ${config.networking.hostName} -p ${port} \
        -u /metrics
      '';
    };
  };

  flyingcircus.roles.statshost.prometheusMetricRelabel =
    let
      rename_merge = options:
        [
          {
            source_labels = [ "__name__" ];
            # Only if there is no command set.
            regex = options.regex;
            replacement = "\${1}";
            target_label = options.target_label;
          }
          {
            source_labels = [ "__name__" ];
            regex = options.regex;
            replacement = options.target_name;
            target_label = "__name__";
          }
        ];
    in (
      (rename_merge {
        regex = "netstat_tcp_(.*)";
        target_label = "state";
        target_name = "netstat_tcp";
       })

    );

}

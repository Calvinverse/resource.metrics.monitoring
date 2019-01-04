# frozen_string_literal: true

#
# Cookbook Name:: resource_metrics_monitoring
# Recipe:: kapacitor
#
# Copyright 2018, P. van der Velde
#

#
# INSTALL KAPACITOR
#

file_name = "kapacitor_#{node['kapacitor']['version']}_amd64.deb"
remote_file "#{Chef::Config[:file_cache_path]}/#{file_name}" do
  action :create
  checksum node['kapacitor']['shasums']
  source "#{node['kapacitor']['download_url']}/#{file_name}"
end

dpkg_package 'kapacitor' do
  action :install
  options '--force-confdef --force-confold'
  source "#{Chef::Config[:file_cache_path]}/#{file_name}"
end

service_name = 'kapacitor'
service service_name do
  action :disable
end

#
# DIRECTORIES
#

kapacitor_data_directory = '/var/lib/kapacitor'
directory kapacitor_data_directory do
  action :create
  group node['kapacitor']['service_user']
  mode '0750'
  owner node['kapacitor']['service_group']
end

kapacitor_template_directory = '/etc/kapacitor/load'
directory kapacitor_template_directory do
  action :create
  group node['kapacitor']['service_user']
  mode '0550'
  owner node['kapacitor']['service_group']
end

kapacitor_recordings_directory = '/var/lib/kapacitor/replay'
directory kapacitor_template_directory do
  action :create
  group node['kapacitor']['service_user']
  mode '0750'
  owner node['kapacitor']['service_group']
end

#
# ALLOW KAPACITOR THROUGH THE FIREWALL
#

kapacitor_http_port = node['kapacitor']['port']['http']
firewall_rule 'kapacitor-http' do
  command :allow
  description 'Allow Kapacitor HTTP traffic'
  dest_port kapacitor_http_port
  direction :in
end

#
# CONSUL FILES
#

file '/etc/consul/conf.d/kapacitor-http.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "http": "http://localhost:#{kapacitor_http_port}/kapacitor/v1/ping",
              "id": "kapacitor_http_health_check",
              "interval": "30s",
              "method": "GET",
              "name": "Kapacitor HTTP health check",
              "timeout": "5s"
            }
          ],
          "enable_tag_override": false,
          "id": "kapacitor_http",
          "name": "metrics",
          "port": #{kapacitor_http_port},
          "tags": [
            "monitoring"
          ]
        }
      ]
    }
  JSON
end

#
# CONSUL-TEMPLATE FILES
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

kapacitor_default_file = node['kapacitor']['config_file_path']
kapacitor_default_template_file = 'kapacitor_start_script.ctmpl'
file "#{consul_template_template_path}/#{kapacitor_default_template_file}" do
  action :create
  content <<~CONFIG
    #!/bin/sh

    {{ if keyExists "config/services/consul/domain" }}
    {{ if keyExists "config/services/metrics/protocols/http/host" }}
    {{ if keyExists "config/services/metrics/protocols/http/port" }}
    echo "Write the Kapacitor configuration ..."
    cat <<'EOT' > #{kapacitor_default_file}
    # The hostname of this node.
    # Must be resolvable by any configured InfluxDB hosts.
    hostname = "{{ file "/etc/hostname" | trimSpace }}"
    # Directory for storing a small amount of metadata about the server.
    data_dir = "#{kapacitor_data_directory}"

    # Default retention-policy, if a write is made to Kapacitor and
    # it does not have a retention policy associated with it,
    # then the retention policy will be set to this value
    default-retention-policy = ""

    [http]
      # HTTP API Server for Kapacitor
      # This server is always on,
      # it serves both as a write endpoint
      # and as the API endpoint for all other
      # Kapacitor calls.
      bind-address = ":#{kapacitor_http_port}"
      log-enabled = true
      write-tracing = false
      pprof-enabled = false
      https-enabled = false
      # https-certificate = "/etc/ssl/kapacitor.pem"
      ### Use a separate private key location.
      # https-private-key = ""

    [config-override]
      # Enable/Disable the service for overridding configuration via the HTTP API.
      enabled = true

    [logging]
        # Destination for logs
        # Can be a path to a file or 'STDOUT', 'STDERR'.
        file = "STDOUT"
        # Logging level can be one of:
        # DEBUG, INFO, ERROR
        # HTTP logging can be disabled in the [http] config section.
        level = "INFO"

    [load]
      # Enable/Disable the service for loading tasks/templates/handlers
      # from a directory
      enabled = true
      # Directory where task/template/handler files are set
      dir = "#{kapacitor_template_directory}"


    [replay]
      # Where to store replay files, aka recordings.
      dir = "#{kapacitor_recordings_directory}"

    [storage]
      # Where to store the Kapacitor boltdb database
      boltdb = "#{kapacitor_data_directory}/kapacitor.db"

    # Multiple InfluxDB configurations can be defined.
    # Exactly one must be marked as the default.
    # Each one will be given a name and can be referenced in batch queries and InfluxDBOut nodes.
    [[influxdb]]
      # Connect to an InfluxDB cluster
      # Kapacitor can subscribe, query and write to this cluster.
      # Using InfluxDB is not required and can be disabled.
      enabled = true
      default = true
      name = "InfluxDB"
      urls = ["http://{{ keyOrDefault "config/services/metrics/protocols/http/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "unknown" }}:{{ keyOrDefault "config/services/metrics/protocols/http/port" "80" }}"]
      username = ""
      password = ""
      timeout = 0

      # Do not verify the TLS/SSL certificate.
      # This is insecure.
      insecure-skip-verify = true

      # Maximum time to try and connect to InfluxDB during startup
      startup-timeout = "5m"

      # Turn off all subscriptionSs
      disable-subscriptions = false

      # Subscription mode is either "cluster" or "server"
      subscription-mode = "cluster"

      # Which protocol to use for subscriptions
      # one of 'udp', 'http', or 'https'.
      subscription-protocol = "http"

      # Subscriptions resync time interval
      # Useful if you want to subscribe to new created databases
      # without restart Kapacitord
      subscriptions-sync-interval = "1m0s"

      # Override the global hostname option for this InfluxDB cluster.
      # Useful if the InfluxDB cluster is in a separate network and
      # needs special config to connect back to this Kapacitor instance.
      # Defaults to `hostname` if empty.
      kapacitor-hostname = ""

      # Override the global http port option for this InfluxDB cluster.
      # Useful if the InfluxDB cluster is in a separate network and
      # needs special config to connect back to this Kapacitor instance.
      # Defaults to the port from `[http] bind-address` if 0.
      http-port = 0

      # Host part of a bind address for UDP listeners.
      # For example if a UDP listener is using port 1234
      # and `udp-bind = "hostname_or_ip"`,
      # then the UDP port will be bound to `hostname_or_ip:1234`
      # The default empty value will bind to all addresses.
      udp-bind = ""
      # Subscriptions use the UDP network protocl.
      # The following options of for the created UDP listeners for each subscription.
      # Number of packets to buffer when reading packets off the socket.
      udp-buffer = 1000
      # The size in bytes of the OS read buffer for the UDP socket.
      # A value of 0 indicates use the OS default.
      udp-read-buffer = 0

      [influxdb.subscriptions]
        # Set of databases and retention policies to subscribe to.
        # If empty will subscribe to all, minus the list in
        # influxdb.excluded-subscriptions
        #
        # Format
        # db_name = <list of retention policies>
        #
        # Example:
        # my_database = [ "default", "longterm" ]
      [influxdb.excluded-subscriptions]
        # Set of databases and retention policies to exclude from the subscriptions.
        # If influxdb.subscriptions is empty it will subscribe to all
        # except databases listed here.
        #
        # Format
        # db_name = <list of retention policies>
        #
        # Example:
        # my_database = [ "default", "longterm" ]

    [smtp]
      # Configure an SMTP email server
      # Will use TLS and authentication if possible
      # Only necessary for sending emails from alerts.
      enabled = false
      host = "{{ keyOrDefault "config/environment/mail/smtp/host" "smtp.example.com" }}"
      port = 25
      username = ""
      password = ""
      # From address for outgoing mail
      from = "monitorin.metrics@{{ key "config/environment/mail/suffix" }}"
      # List of default To addresses.
      # to = ["oncall@example.com"]

      # Skip TLS certificate verify when connecting to SMTP server
      no-verify = false
      # Close idle connections after timeout
      idle-timeout = "30s"

      # If true the all alerts will be sent via Email
      # without explicitly marking them in the TICKscript.
      global = false
      # Only applies if global is true.
      # Sets all alerts in state-changes-only mode,
      # meaning alerts will only be sent if the alert state changes.
      state-changes-only = false

    [reporting]
      # Send usage statistics
      # every 12 hours to Enterprise.
      enabled = false
      # url = "https://usage.influxdata.com"

    [stats]
      # Emit internal statistics about Kapacitor.
      # To consume these stats create a stream task
      # that selects data from the configured database
      # and retention policy.
      #
      # Example:
      #  stream|from().database('_kapacitor').retentionPolicy('autogen')...
      #
      enabled = true
      stats-interval = "10s"
      database = "services"
      retention-policy= "autogen"

    [udf]
    # Configuration for UDFs (User Defined Functions)
    [udf.functions]
        # Example go UDF.
        # First compile example:
        #   go build -o avg_udf ./udf/agent/examples/moving_avg.go
        #
        # Use in TICKscript like:
        #   stream.goavg()
        #           .field('value')
        #           .size(10)
        #           .as('m_average')
        #
        # uncomment to enable
        #[udf.functions.goavg]
        #   prog = "./avg_udf"
        #   args = []
        #   timeout = "10s"

        # Example python UDF.
        # Use in TICKscript like:
        #   stream.pyavg()
        #           .field('value')
        #           .size(10)
        #           .as('m_average')
        #
        # uncomment to enable
        #[udf.functions.pyavg]
        #   prog = "/usr/bin/python2"
        #   args = ["-u", "./udf/agent/examples/moving_avg.py"]
        #   timeout = "10s"
        #   [udf.functions.pyavg.env]
        #       PYTHONPATH = "./udf/agent/py"

        # Example UDF over a socket
        #[udf.functions.myCustomUDF]
        #   socket = "/path/to/socket"
        #   timeout = "10s"

    # MQTT client configuration.
    #  Mutliple different clients may be configured by
    #  repeating [[mqtt]] sections.
    [[mqtt]]
      enabled = false
      # Unique name for this broker configuration
      name = "localhost"
      # Whether this broker configuration is the default
      default = true
      # URL of the MQTT broker.
      # Possible protocols include:
      #  tcp - Raw TCP network connection
      #  ssl - TLS protected TCP network connection
      #  ws  - Websocket network connection
      url = "tcp://localhost:1883"

      # TLS/SSL configuration
      # A CA can be provided without a key/cert pair
      #   ssl-ca = "/etc/kapacitor/ca.pem"
      # Absolutes paths to pem encoded key and cert files.
      #   ssl-cert = "/etc/kapacitor/cert.pem"
      #   ssl-key = "/etc/kapacitor/key.pem"

      # Unique ID for this MQTT client.
      # If empty used the value of "name"
      client-id = ""

      # Username
      username = ""
      # Password
      password = ""

    ##################################
    # Input Methods, same as InfluxDB
    #

    [collectd]
      enabled = false
      bind-address = ":25826"
      database = "collectd"
      retention-policy = ""
      batch-size = 1000
      batch-pending = 5
      batch-timeout = "10s"
      typesdb = "/usr/share/collectd/types.db"

    [opentsdb]
      enabled = false
      bind-address = ":4242"
      database = "opentsdb"
      retention-policy = ""
      consistency-level = "one"
      tls-enabled = false
      certificate = "/etc/ssl/influxdb.pem"
      batch-size = 1000
      batch-pending = 5
      batch-timeout = "1s"
    EOT

    chown #{node['kapacitor']['service_user']}:#{node['kapacitor']['service_group']} #{kapacitor_default_file}
    chmod 550 #{kapacitor_default_file}

    if ( ! $(systemctl is-enabled --quiet #{service_name}) ); then
      systemctl enable #{service_name}

      while true; do
        if ( (systemctl is-enabled --quiet #{service_name}) ); then
            break
        fi

        sleep 1
      done
    fi

    if ( ! (systemctl is-active --quiet #{service_name}) ); then
      systemctl start #{service_name}

      while true; do
        if ( (systemctl is-active --quiet #{service_name}) ); then
            break
        fi

        sleep 1
      done
    else
      systemctl restart #{service_name}
    fi

    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Capacitor."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Capacitor."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Capacitor."
    {{ end }}
  CONFIG
  group 'root'
  mode '0550'
  owner 'root'
end

kapacitor_start_script_file = '/tmp/kapacitor_start.sh'
file "#{consul_template_config_path}/kapacitor_start_script.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{kapacitor_default_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{kapacitor_start_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{kapacitor_start_script_file}"

      # This is the maximum amount of time to wait for the optional command to
      # return. Default is 30s.
      command_timeout = "15s"

      # Exit with an error when accessing a struct or map field/key that does not
      # exist. The default behavior will print "<no value>" when accessing a field
      # that does not exist. It is highly recommended you set this to "true" when
      # retrieving secrets from Vault.
      error_on_missing_key = false

      # This is the permission to render the file. If this option is left
      # unspecified, Consul Template will attempt to match the permissions of the
      # file that already exists at the destination path. If no file exists at that
      # path, the permissions are 0644.
      perms = 0550

      # This option backs up the previously rendered template at the destination
      # path before writing a new one. It keeps exactly one backup. This option is
      # useful for preventing accidental changes to the data without having a
      # rollback strategy.
      backup = true

      # These are the delimiters to use in the template. The default is "{{" and
      # "}}", but for some templates, it may be easier to use a different delimiter
      # that does not conflict with the output file itself.
      left_delimiter  = "{{"
      right_delimiter = "}}"

      # This is the `minimum(:maximum)` to wait before rendering a new template to
      # disk and triggering a command, separated by a colon (`:`). If the optional
      # maximum value is omitted, it is assumed to be 4x the required minimum value.
      # This is a numeric time with a unit suffix ("5s"). There is no default value.
      # The wait value for a template takes precedence over any globally-configured
      # wait.
      wait {
        min = "2s"
        max = "10s"
      }
    }
  HCL
  group 'root'
  mode '0550'
  owner 'root'
end

#
# TELEGRAF
#

telegraf_service = 'telegraf'
telegraf_config_directory = node['telegraf']['config_directory']
telegraf_kapacitor_inputs_template_file = node['kapacitor']['telegraf']['consul_template_inputs_file']
file "#{consul_template_template_path}/#{telegraf_kapacitor_inputs_template_file}" do
  action :create
  content <<~CONF
    # Telegraf Configuration

    ###############################################################################
    #                            INPUT PLUGINS                                    #
    ###############################################################################

    [[inputs.kapacitor]]
      ## Multiple URLs from which to read Kapacitor-formatted JSON
      ## Default is "http://localhost:9092/kapacitor/v1/debug/vars".
      urls = [
        "http://localhost:#{kapacitor_http_port}/kapacitor/v1/debug/vars"
      ]

      ## Time limit for http requests
      timeout = "5s"

      ## Optional TLS Config
      # tls_ca = "/etc/telegraf/ca.pem"
      # tls_cert = "/etc/telegraf/cert.pem"
      # tls_key = "/etc/telegraf/key.pem"
      ## Use TLS but skip chain & host verification
      # insecure_skip_verify = false
      [inputs.kapacitor.tags]
        influxdb_database = "{{ keyOrDefault "config/services/metrics/databases/services" "services" }}"
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

file "#{consul_template_config_path}/telegraf_kapacitor_inputs.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{telegraf_kapacitor_inputs_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{telegraf_config_directory}/inputs_kapacitor.conf"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "/bin/bash -c 'chown #{node['telegraf']['service_user']}:#{node['telegraf']['service_group']} #{telegraf_config_directory}/inputs_kapacitor.conf && systemctl restart #{telegraf_service}'"

      # This is the maximum amount of time to wait for the optional command to
      # return. Default is 30s.
      command_timeout = "15s"

      # Exit with an error when accessing a struct or map field/key that does not
      # exist. The default behavior will print "<no value>" when accessing a field
      # that does not exist. It is highly recommended you set this to "true" when
      # retrieving secrets from Vault.
      error_on_missing_key = false

      # This is the permission to render the file. If this option is left
      # unspecified, Consul Template will attempt to match the permissions of the
      # file that already exists at the destination path. If no file exists at that
      # path, the permissions are 0644.
      perms = 0550

      # This option backs up the previously rendered template at the destination
      # path before writing a new one. It keeps exactly one backup. This option is
      # useful for preventing accidental changes to the data without having a
      # rollback strategy.
      backup = true

      # These are the delimiters to use in the template. The default is "{{" and
      # "}}", but for some templates, it may be easier to use a different delimiter
      # that does not conflict with the output file itself.
      left_delimiter  = "{{"
      right_delimiter = "}}"

      # This is the `minimum(:maximum)` to wait before rendering a new template to
      # disk and triggering a command, separated by a colon (`:`). If the optional
      # maximum value is omitted, it is assumed to be 4x the required minimum value.
      # This is a numeric time with a unit suffix ("5s"). There is no default value.
      # The wait value for a template takes precedence over any globally-configured
      # wait.
      wait {
        min = "2s"
        max = "10s"
      }
    }
  HCL
  group 'root'
  mode '0550'
  owner 'root'
end

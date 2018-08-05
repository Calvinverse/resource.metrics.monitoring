# frozen_string_literal: true

#
# Cookbook Name:: resource_metrics_monitoring
# Recipe:: chronograf
#
# Copyright 2018, P. van der Velde
#

#
# INSTALL CHRONOGRAF
#

file_name = "chronograf_#{node['chronograf']['version']}_amd64.deb"
remote_file "#{Chef::Config[:file_cache_path]}/#{file_name}" do
  action :create
  checksum node['chronograf']['shasums']
  source "#{node['chronograf']['download_url']}/#{file_name}"
end

dpkg_package 'chronograf' do
  action :install
  options '--force-confdef --force-confold'
  source "#{Chef::Config[:file_cache_path]}/#{file_name}"
end

service_name = 'chronograf'
service service_name do
  action :enable
end

#
# ALLOW CHRONOGRAF THROUGH THE FIREWALL
#

chronograf_http_port = node['chronograf']['port']['http']
firewall_rule 'chronograf-http' do
  command :allow
  description 'Allow Chronograf HTTP traffic'
  dest_port chronograf_http_port
  direction :in
end

#
# CONSUL FILES
#

proxy_path = node['chronograf']['proxy_path']
file '/etc/consul/conf.d/chronograf-http.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "http": "http://localhost:#{chronograf_http_port}/api/health",
              "id": "chronograf_http_health_check",
              "interval": "30s",
              "method": "GET",
              "name": "Chronograf HTTP health check",
              "timeout": "5s"
            }
          ],
          "enable_tag_override": false,
          "id": "chronograf_http",
          "name": "metrics",
          "port": #{chronograf_http_port},
          "tags": [
            "admin",
            "edgeproxyprefix-/#{proxy_path}"
          ]
        }
      ]
    }
  JSON
end

#
# FLAG FILES
#

flag_default = '/var/log/chronograf_default.log'
file flag_default do
  action :create
  content <<~TXT
    NotInitialized
  TXT
  group 'root'
  mode '0770'
  owner 'root'
end

#
# CONSUL-TEMPLATE FILES
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

kapacitor_http_port = node['kapacitor']['port']['http']

chronograf_default_file = node['chronograf']['config_file_path']
chronograf_default_template_file = 'chronograf_start_script.ctmpl'
file "#{consul_template_template_path}/#{chronograf_default_template_file}" do
  action :create
  content <<~CONFIG
    #!/bin/sh

    {{ if keyExists "config/services/consul/domain" }}
    {{ if keyExists "config/services/metrics/protocols/http/host" }}
    {{ if keyExists "config/services/metrics/protocols/http/port" }}
    FLAG=$(cat #{flag_default})
    if [ "$FLAG" = "NotInitialized" ]; then
        echo "Write the Chronograf configuration ..."
        cat <<'EOT' > #{chronograf_default_file}
    HOST=0.0.0.0
    PORT=#{chronograf_http_port}
    BASE_PATH=#{proxy_path}

    INFLUXDB_URL=http//{{ key "config/services/metrics/protocols/http/host" }}.service.{{ key "config/services/consul/domain" }}:{{ key "config/services/metrics/protocols/http/port" }}

    KAPACITOR_URL=http://127.0.0.1:#{kapacitor_http_port}
    EOT
        chown #{node['chronograf']['service_user']}:#{node['chronograf']['service_group']} #{chronograf_default_file}
        chmod 550 #{chronograf_default_file}

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

        echo "Initialized" > #{flag_default}
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

chronograf_start_script_file = '/tmp/chronograf_start.sh'
file "#{consul_template_config_path}/chronograf_start_script.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{chronograf_default_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{chronograf_start_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{chronograf_start_script_file}"

      # This is the maximum amount of time to wait for the optional command to
      # return. Default is 30s.
      command_timeout = "60s"

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

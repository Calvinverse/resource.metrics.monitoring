# frozen_string_literal: true

require 'spec_helper'

describe 'resource_metrics_monitoring::chronograf' do
  context 'installs Chronograf' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    install_version = '1.7.5'
    file_name = "chronograf_#{install_version}_amd64.deb"
    it 'downloads chronograf' do
      expect(chef_run).to create_remote_file("#{Chef::Config[:file_cache_path]}/#{file_name}").with(
        source: "https://dl.influxdata.com/chronograf/releases/#{file_name}"
      )
    end

    it 'installs chronograf' do
      expect(chef_run).to install_dpkg_package('chronograf').with(
        options: ['--force-confdef', '--force-confold'],
        source: "#{Chef::Config[:file_cache_path]}/#{file_name}"
      )
    end

    it 'disables the chronograf service' do
      expect(chef_run).to disable_service('chronograf')
    end
  end

  context 'allows Chronograf through the firewall' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Chronograf http port' do
      expect(chef_run).to create_firewall_rule('chronograf-http').with(
        command: :allow,
        dest_port: 8888,
        direction: :in
      )
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_chronograf_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "http": "http://localhost:8888/dashboards/monitoring/chronograf/v1",
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
            "port": 8888,
            "tags": [
              "admin",
              "edgeproxyprefix-/dashboards/monitoring"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/chronograf-http.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/chronograf-http.json')
        .with_content(consul_chronograf_config_content)
    end
  end

  context 'lets chronograf through the firewall' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Chronograf http port' do
      expect(chef_run).to create_firewall_rule('chronograf-http').with(
        command: :allow,
        dest_port: 8888,
        direction: :in
      )
    end
  end

  context 'adds the consul-template files' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    chronograf_run_script_template_content = <<~CONF
      #!/bin/sh

      {{ if keyExists "config/services/consul/domain" }}
      {{ if keyExists "config/services/metrics/protocols/http/host" }}
      {{ if keyExists "config/services/metrics/protocols/http/port" }}

      echo "Write the Chronograf configuration ..."
      cat <<'EOT' > /etc/default/chronograf
      HOST=0.0.0.0
      PORT=8888
      BASE_PATH=/dashboards/monitoring

      INFLUXDB_URL=http://{{ key "config/services/metrics/protocols/http/host" }}.service.{{ key "config/services/consul/domain" }}:{{ key "config/services/metrics/protocols/http/port" }}

      KAPACITOR_URL=http://127.0.0.1:9092
      EOT

      chown chronograf:chronograf /etc/default/chronograf
      chmod 550 /etc/default/chronograf

      if ( ! $(systemctl is-enabled --quiet chronograf) ); then
        systemctl enable chronograf

        while true; do
          if ( (systemctl is-enabled --quiet chronograf) ); then
              break
          fi

          sleep 1
        done
      fi

      if ( ! (systemctl is-active --quiet chronograf) ); then
        systemctl start chronograf

        while true; do
          if ( (systemctl is-active --quiet chronograf) ); then
              break
          fi

          sleep 1
        done
      else
        systemctl restart chronograf
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
    CONF
    it 'creates telegraf chronograf input template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/chronograf_start_script.ctmpl')
        .with_content(chronograf_run_script_template_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    consul_template_chronograf_run_script_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/chronograf_start_script.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/chronograf_start.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "sh /tmp/chronograf_start.sh"

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
    CONF
    it 'creates chronograf_start_script.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/chronograf_start_script.hcl')
        .with_content(consul_template_chronograf_run_script_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end
  end
end

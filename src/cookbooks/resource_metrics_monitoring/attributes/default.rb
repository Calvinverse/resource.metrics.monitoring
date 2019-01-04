# frozen_string_literal: true

#
# CHRONOGRAF
#

default['chronograf']['service_user'] = 'chronograf'
default['chronograf']['service_group'] = 'chronograf'

default['chronograf']['version'] = '1.7.5'
default['chronograf']['shasums'] = '41957fea7266e2827d1e569ae0feb35dbe73bf6df34e5b3bf130eda3428bbcbb'
default['chronograf']['download_url'] = 'https://dl.influxdata.com/chronograf/releases'

default['chronograf']['port']['http'] = 8888
default['chronograf']['proxy_path'] = 'dashboards/monitoring'

default['chronograf']['config_file_path'] = '/etc/default/chronograf'

#
# CONSULTEMPLATE
#

default['consul_template']['config_path'] = '/etc/consul-template.d/conf'
default['consul_template']['template_path'] = '/etc/consul-template.d/templates'

#
# FIREWALL
#

# Allow communication on the loopback address (127.0.0.1 and ::1)
default['firewall']['allow_loopback'] = true

# Do not allow MOSH connections
default['firewall']['allow_mosh'] = false

# Do not allow WinRM (which wouldn't work on Linux anyway, but close the ports just to be sure)
default['firewall']['allow_winrm'] = false

# No communication via IPv6 at all
default['firewall']['ipv6_enabled'] = false

#
# KAPACITOR
#

default['kapacitor']['service_user'] = 'kapacitor'
default['kapacitor']['service_group'] = 'kapacitor'

default['kapacitor']['version'] = '1.5.2'
default['kapacitor']['shasums'] = 'f09d9faf09f69e5a5b7570fa4b69cc86c0104068fb3e90d07bebd7b4a64425b4'
default['kapacitor']['download_url'] = 'https://dl.influxdata.com/kapacitor/releases'

default['kapacitor']['port']['http'] = 9092

default['kapacitor']['config_file_path'] = '/etc/kapacitor/kapacitor.conf'
default['kapacitor']['telegraf']['consul_template_inputs_file'] = 'telegraf_kapacitor_inputs.ctmpl'

#
# TELEGRAF
#

default['telegraf']['service_user'] = 'telegraf'
default['telegraf']['service_group'] = 'telegraf'
default['telegraf']['config_directory'] = '/etc/telegraf/telegraf.d'

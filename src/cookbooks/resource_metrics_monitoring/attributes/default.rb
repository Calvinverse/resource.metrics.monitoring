# frozen_string_literal: true

#
# CHRONOGRAF
#

default['chronograf']['service_user'] = 'chronograf'
default['chronograf']['service_group'] = 'chronograf'

default['chronograf']['version'] = '1.6.0'
default['chronograf']['shasums'] = '9fc74eb19f001cd1a2936f20a98f9d9343ace372e860eddc8ec42b0ec04540a0'
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

default['kapacitor']['version'] = '1.5.0'
default['kapacitor']['shasums'] = 'ed0c8e3f7758f679bc11fca3dbb91904aeb2e49bb9e67fb53ebaa209dad79358'
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

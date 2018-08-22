Describe 'The kapacitor application' {
    Context 'is installed' {
        It 'with binaries in /usr/bin/kapacitor' {
            '/usr/bin/kapacitor' | Should Exist
        }

        It 'with configuration in /etc/kapacitor' {
            '/etc/kapacitor/kapacitor.conf' | Should Exist
        }
    }

    Context 'has been daemonized' {
        $serviceConfigurationPath = '/lib/systemd/system/kapacitor.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
               $false | Should Be $true
            }
        }

        $expectedContent = @'
# If you modify this, please also make sure to edit init.sh

[Unit]
Description=Time series data processing engine.
Documentation=https://github.com/influxdb/kapacitor
After=network.target

[Service]
User=kapacitor
Group=kapacitor
LimitNOFILE=65536
EnvironmentFile=-/etc/default/kapacitor
ExecStart=/usr/bin/kapacitord -config /etc/kapacitor/kapacitor.conf $KAPACITOR_OPTS
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status kapacitor
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'kapacitor.service - Time series data processing engine.'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }
}

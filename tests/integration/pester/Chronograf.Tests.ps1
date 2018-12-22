Describe 'The chronograf application' {
    Context 'is installed' {
        It 'with binaries in /usr/bin/chronograf' {
            '/usr/bin/chronograf' | Should Exist
        }

        It 'with configuration in /etc/default' {
            '/etc/default/chronograf' | Should Exist
        }
    }

    Context 'has been daemonized' {
        $serviceConfigurationPath = '/lib/systemd/system/chronograf.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
               $false | Should Be $true
            }
        }

        $expectedContent = @'
# If you modify this, please also make sure to edit init.sh

[Unit]
Description=Open source monitoring and visualization UI for the entire TICK stack.
Documentation="https://www.influxdata.com/time-series-platform/chronograf/"
After=network-online.target

[Service]
User=chronograf
Group=chronograf
Environment="HOST=0.0.0.0"
Environment="PORT=8888"
Environment="BOLT_PATH=/var/lib/chronograf/chronograf-v1.db"
Environment="CANNED_PATH=/usr/share/chronograf/canned"
EnvironmentFile=-/etc/default/chronograf
ExecStart=/usr/bin/chronograf $CHRONOGRAF_OPTS
KillMode=control-group
Restart=on-failure

[Install]
WantedBy=multi-user.target

'@
        # There's a rogue space at the end of one of the lines which breaks the comparison
        $serviceFileContent = Get-Content $serviceConfigurationPath | Foreach-Object { $_.Trim() } | Out-String
        $systemctlOutput = & systemctl status chronograf
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'chronograf.service - Open source monitoring and visualization UI for the entire TICK stack.'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }
}

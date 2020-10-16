# resource.metrics.monitoring

This repository contains the source code necessary to build Ubuntu Hyper-V hard-drives containing the
[Chronograf](https://www.influxdata.com/time-series-platform/chronograf/) and
[Kapacitor](https://www.influxdata.com/time-series-platform/kapacitor/) applications.

## Image

The image is created by using the [Linux base image](https://github.com/Calvinverse/base.linux)
and amending it using a [Chef](https://www.chef.io/chef/) cookbook which installs chronograf and
kapacitor.

### Contents

In addition to the default applications installed in the template image the following items are
also installed and configured:

* [Chronograf](https://www.influxdata.com/time-series-platform/chronograf/) - The UI used to
  interact with the Influx database and Kapacitor.
* [Kapacitor](https://www.influxdata.com/time-series-platform/kapacitor/)

### Configuration

The configuration for the Chronograf and Kapacitor instances comes from a
[Consul-Template](https://github.com/hashicorp/consul-template) template file which replaces some
of the template parameters with values from the Consul Key-Value store.

#### Chronograf

The Chronograf configuration only requires the address for the Influx service.

#### Kapacitor

The Kapacitor configuration requires

* The address of the Influx service
* Information about the email domain in order to send emails

### Provisioning

No additional configuration is applied other than the default one for the base image.

### Logs

No additional configuration is applied other than the default one for the base image.

### Metrics

Metrics are collected by [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/).

## Build, test and release

The build process follows the standard procedure for building Calvinverse images.

## Deploy

* Download the new image to one of the Hyper-V hosts.
* Create a new directory in one of the designated workspace hard-disks (workspace 1 - 6) for the
  image under the suitable environment folder (e.g. `test-01` when adding the image to
  the test environment) and copy the image VHDX file there
* Create a VM that points to the image VHDX file with the following settings
  * Name: `<Environment>_<ResourceName>-<Number>`
  * Generation: 2
  * RAM: 1024 Mb. Do *not* use dynamic memory
  * Network: VM
  * Hard disk: Use existing. Copy the path to the VHDX file
* Update the VM settings:
  * Enable secure boot. Use the Microsoft UEFI Certificate Authority
  * Attach a DVD image that points to an ISO file containing the settings for the environment. These
    are normally found in the output of the
    [Calvinverse.Infrastructure](https://github.com/Calvinverse/calvinverse.infrastructure)
    repository. Pick the correct ISO for the task, in this case the `Linux Consul Client` image
* Start the VM, it should automatically connect to the correct environment once it has provisioned
* Remove the old VM
  * SSH into the host
  * Issue the `consul leave` command
  * Shut the machine down with the `sudo shutdown now` command
  * Once the machine has stopped, delete it

## Usage

The Chronograf webpage will be made available from the proxy at the `/dashboards/monitoring` sub-address.


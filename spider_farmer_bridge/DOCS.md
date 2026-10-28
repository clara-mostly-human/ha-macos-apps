# Spider Farmer Bridge

Local control of Spider Farmer GGS grow controllers (control boxes, power
strips, light controllers, SE lights) from Home Assistant, natively on macOS.

The controllers talk MQTT over TLS to `sf.mqtt.spider-farmer.com:8883`. This
app runs the bridge from
[spider_farmer_bridge](https://github.com/clara-mostly-human/spider_farmer_bridge):
it accepts that connection instead (it holds the certificate the controllers
trust), decodes everything, and either relays it to the Spider Farmer cloud,
so the Spider Farmer phone app keeps working, or keeps it entirely local.
Home Assistant's Spider Farmer Bridge integration connects to the app, the way
the Matter integration connects to Matter Server.

## Setup

1. Install and start this app.
2. Install the Spider Farmer Bridge integration (HACS custom repository
   `clara-mostly-human/spider_farmer_bridge`). Home Assistant then offers to
   set it up for this app.
3. Send the controllers' cloud connection to this Mac: on the router, a
   destination NAT rule for the controller's IP address, TCP port 8883, to
   this Mac's IP address, port 8883. When the controller and this Mac share a
   subnet, the rule also needs masquerade (source NAT), or the controller
   drops the replies.

## Options

- **Log level**: the app's log.

Device control, local-only mode (block the cloud) and the offline timeout are
set in the integration's options; it hands them to the app.

## Ports

- **8883/tcp**: the controllers connect here.
- **8484/tcp**: the integration's WebSocket API, bound to localhost.

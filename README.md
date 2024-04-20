# Athena container

Athena container are the devices code that runs on an esp32 with Toit firmware. Athena is a Fleet Management system developed as an bachelor project. When this code is installed as an container on an esp32 microcontroller with Toit firmware, will it be possible to monitor the device status and make OTA updates to it.

## Prerequisites

1. Have an esp32 ready with the [Toit Jaguar firmware](https://github.com/toitlang/jaguar) flashed on to it.
2. When the esp32 has the Toit Jaguar firmware and are configured to your Wi-Fi, are you ready to move on.

## Usage

Install required toit packages:
```jag
jag pkg install
```


Define the host connection, all of the values should be change according to your MQTT broker setup:
```toit
// "HOST" is the ip address of the MQTT broker.
HOST ::= "127.0.0.1"

// "PORT" is the port of the MQTT broker.
PORT ::= 1883

// "USERNAME" is the username for authentication with the MQTT broker.
USERNAME ::= "admin"

// "PASSWORD" is the password for authentication with the MQTT broker.
PASSWORD ::= "admin"
```

Define the publish topic - "TOPIC" is the topic that the payload will be published to.
```toit
// "TOPIC" is the MQTT topic that the device should publish to.
TOPIC ::= "lifecycle/status"
```

Install the Athena container on your esp32:
```jag
jag container install Athena athena.toit
```

## Disclaimer

This repo is an work in progress at the moment and does not have any stable releases. We are working on it as an bachelor project and their may never be an stable release.
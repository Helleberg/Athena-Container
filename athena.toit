import mqtt
import uuid
import system.storage
import device
import system
import system.containers
import encoding.json

HOST ::= "192.168.1.228"                   // Broker ip address
PORT ::= 1883                               // Broker port
USERNAME ::= "admin"                        // Broker auth username
PASSWORD ::= "password"                     // Broker auth password

main:

  print device.hardware-id
  print system.app-sdk-version
  print system.architecture
  print system.platform

  /* // Initiate client for mqtt connection
  client := mqtt.Client --host=HOST --port=PORT

  // mqtt session settings for client acknowledge and authentication
  options := mqtt.SessionOptions
      --client-id = device.hardware-id.to-string
      --username  = USERNAME
      --password  = PASSWORD

  // Start client with session settings
  client.start --options=options

  print "[Athena] INFO: Connected to MQTT broker"

  task:: lifecycle client */

init client/mqtt.Client:
  print "[Athena] INFO: Initializing device"

  // Create new device payload
  new_device := json.encode {
    "uuid": "$device.hardware-id",
    "toit_firmware_version": "$firmware.uri",
    "athena_version": "v1.0.0"
  }

  // Publish the payload to the broker with specified topic
  client.publish "devices/new" new_device --qos=1 --retain=true

lifecycle client/mqtt.Client:
  init client

  // Lifecycle loop
  while true:
    // Create status lifecycle payload
    status := json.encode {
      "value": "ESP with Toit firmware running Athena container",
      "uuid": "$device.hardware-id",
      "toit_firmware_version": "$firmware.uri",
      "athena_version": "v1.0.0",
      "now": "$Time.now.ms-since-epoch"
    }

    // Publish the payload to the broker with specified topic
    client.publish "lifecycle/status" status
    sleep --ms=1000
  
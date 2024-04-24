import mqtt
import uuid
import http
import net
import system.storage
import device
import system
import system.firmware
import encoding.json

HOST ::= "192.168.20.248"                  // Broker ip address
PORT ::= 1883                               // Broker port
USERNAME ::= "admin"                        // Broker auth username
PASSWORD ::= "password"                     // Broker auth password

main:

  // Initiate client for mqtt connection
  client := mqtt.Client --host=HOST --port=PORT

  // mqtt session settings for client acknowledge and authentication
  options := mqtt.SessionOptions
      --client-id = device.hardware-id.to-string
      --username  = USERNAME
      --password  = PASSWORD

  // Start client with session settings
  client.start --options=options

  print "[Athena] INFO: Connected to MQTT broker"

  task:: lifecycle client

init client/mqtt.Client:
  print "[Athena] INFO: Initializing device"

  // Create new device payload
  new_device := json.encode {
    "uuid": "$device.hardware-id",
    "toit_firmware_version": "$system.app-sdk-version",
    "athena_version": "v1.0.0"
  }

  // Publish the payload to the broker with specified topic
  client.publish "devices/new" new_device --qos=1 --retain=true

  // Subscribe to the firmware update topic
  client.subscribe "firmware/update/$device.hardware-id":: | topic/string payload/ByteArray |
    decoded := json.decode payload
    print "Received new information on '$topic': $decoded"
    // Run install firmware logic

lifecycle client/mqtt.Client:
  init client

  print "[Athena] INFO: Start lifecycle - Sending ping every 30 seconds"

  // Lifecycle loop
  while true:
    // Create status lifecycle payload
    status := json.encode {
      "uuid": "$device.hardware-id",
      "toit_firmware_version": "$system.app-sdk-version",
      "athena_version": "v1.0.0"
    }

    // Publish the payload to the broker with specified topic
    client.publish "lifecycle/status" status --qos=0
    sleep --ms=30000

firmware-update deviceUUID/string updateURL/string:
  if deviceUUID == device.hardware-id:
    network := net.open
    client := http.Client network
    try:
      response := client.get --uri=updateURL
      // install-firmware response.body
    finally:
      client.close
      network.close
    firmware.upgrade

  else:
    print "UUID does not match"

// install-firmware reader/io.Reader -> none:
//   firmware-size := reader.content-size
//   print "installing firmware with $firmware-size bytes"
//   written-size := 0
//   writer := firmware.FirmwareWriter 0 firmware-size
//   try:
//     last := null
//     while data := reader.read:
//       written-size += data.size
//       writer.write data
//       percent := (written-size * 100) / firmware-size
//       if percent != last:
//         print "installing firmware with $firmware-size bytes ($percent%)"
//         last = percent
//     writer.commit
//     print "installed firmware; ready to update on chip reset"
//   finally:
//     writer.close
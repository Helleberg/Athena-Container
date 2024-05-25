import mqtt
import uuid
import http
import http show Headers
import io
import net
import device
import system
import system.firmware
import encoding.json

HOST ::= "192.168.1.228"                    // Broker ip address
PORT ::= 1883                               // Broker port
GATEWAY_PORT ::= 8285                       // Gateway API port
USERNAME ::= "admin"                        // Broker auth username
PASSWORD ::= "password"                     // Broker auth password

ATHENA_VERSION ::= "v1.0.1"                 // VERSION of current file

main:
  routes := {
    "firmware/update/$device.hardware-id.to-string": :: | topic/string payload/ByteArray |
      decoded := json.decode payload
      // {"uuid": uuid, "token": token}
      print "Received new information on '$topic': $decoded["token"]"
      firmware-update "$device.hardware-id.to-string" "$decoded["token"]"
  }

  // Initiate client for mqtt connection
  client := mqtt.Client --host=HOST --port=PORT --routes=routes

  // mqtt session settings for client acknowledge and authentication
  options := mqtt.SessionOptions
      --client-id = device.hardware-id.to-string
      --username  = USERNAME
      --password  = PASSWORD

  // Start client with session settings
  client.start --options=options

  print "[Athena] INFO: Connected to MQTT broker"

  // Check if firmware validation is pending
  if firmware.is-validation-pending:
    if firmware.validate:
      print "[Athena] INFO: Firmware update validated"
      // Publish firmware update success
      updated := json.encode {
        "message": "Firmware updated successfully",
        "uuid": "$device.hardware-id",
        "toit_firmware_version": "$system.app-sdk-version",
        "athena_version": "$ATHENA_VERSION"
      }

      // Publish the payload to the broker with specified topic
      client.publish "firmware/updated/$device.hardware-id.to-string" updated --qos=0
    else:
      print "[Athena] INFO: Firmware update failed to validate"
      // Publish firmware update error
      updated := json.encode {
        "message": "Firmware update failed to validate",
        "uuid": "$device.hardware-id",
        "toit_firmware_version": "$system.app-sdk-version",
        "athena_version": "$ATHENA_VERSION"
      }

      // Publish the payload to the broker with specified topic
      client.publish "firmware/updated/$device.hardware-id.to-string" updated --qos=0

  task:: lifecycle client

init client/mqtt.Client:
  print "[Athena] INFO: Initializing device"

  // Create new device payload
  new_device := json.encode {
    "uuid": "$device.hardware-id",
    "toit_firmware_version": "$system.app-sdk-version",
    "athena_version": "$ATHENA_VERSION",
    "ip_address": "$net.open.address",
    "jaguar_port": 9000
  }

  // Publish the payload to the broker with specified topic
  client.publish "devices/new" new_device --qos=1 --retain=true

lifecycle client/mqtt.Client:
  init client

  print "[Athena] INFO: Start lifecycle  -  Sending ping every 30 seconds"

  // Lifecycle loop
  while true:
    // Create status lifecycle payload
    status := json.encode {
      "uuid": "$device.hardware-id",
      "toit_firmware_version": "$system.app-sdk-version",
      "athena_version": "$ATHENA_VERSION",
      "ip_address": "$net.open.address",
      "jaguar_port": 9000
    }

    // Publish the payload to the broker with specified topic
    client.publish "lifecycle/status" status --qos=0
    sleep --ms=30000

firmware-update deviceUUID/string token/string:
  if deviceUUID == device.hardware-id.to-string:
    network := net.open
    client := http.Client network
    try:
      print "[ATHENA] INFO: Requesting firmware file"
      header := Headers
      print token
      header.add "Authorization" "Bearer $token"
      response := client.get --uri="http://$HOST:$GATEWAY-PORT/firmware/download/$deviceUUID" --headers=header
      if response.status-code == 200:
        print "Got firmware file"
        install-firmware response.body
      else:
        print "Request Error:"
        print response.body
    finally:
      client.close
      network.close
    firmware.upgrade

  else:
    print "UUID does not match"

install-firmware reader/io.Reader -> none:
  network := net.open
  server-socket := network.tcp-listen 1337
  print server-socket.local-address.port
  print "Listening on http://$network.address:$server-socket.local-address.port/"
    
  clients := []
  server := http.Server --max-tasks=5
    
  firmware-size := reader.content-size
  print "installing firmware with $firmware-size bytes"
  written-size := 0
  writer := firmware.FirmwareWriter 0 firmware-size
    
  try:
    server.listen server-socket:: | request/http.RequestIncoming response-writer/http.ResponseWriter |
      web-socket := server.web-socket request response-writer
      clients.add web-socket
    
      last := null
      while data := reader.read:
        written-size += data.size
        writer.write data
        percent := (written-size * 100) / firmware-size
        if percent != last:
          print "installing firmware with $firmware-size bytes ($percent%)"
          clients.do: it.send "$percent"
          last = percent
    
      writer.commit
      print "installed firmware; ready to update on chip reset"
      // Remove client after upgrade finish
      web-socket.close
      clients.remove web-socket
  finally:
    writer.close

/*install-firmware reader/io.Reader -> none:
  // Create HTTP websocket client
  network := net.open
  server-socket := network.tcp-listen 0
  print server-socket.local-address.port
  port := 1337
  print "Listening on http://$network.address:$port/"

  clients := []
  server := http.Server --max-tasks=5

  firmware-size := reader.content-size
  print "installing firmware with $firmware-size bytes"
  written-size := 0
  writer := firmware.FirmwareWriter 0 firmware-size
  try:
    server.listen server-socket:: | request/http.RequestIncoming response-writer/http.ResponseWriter |
      web-socket := server.web-socket request response-writer
      clients.add web-socket
      last := null
      while data := reader.read:
        written-size += data.size
        writer.write data
        percent := (written-size * 100) / firmware-size
        if percent != last:
          print "installing firmware with $firmware-size bytes ($percent%)"
          clients.do: it.send percent
          last = percent
        // Remvoe client after upgrade finish
        clients.remove web-socket
      writer.commit
      print "installed firmware; ready to update on chip reset"
  finally:
    writer.close*/
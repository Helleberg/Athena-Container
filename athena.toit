import mqtt
import uuid
import http
import http show Headers
import io
import net
import net.wifi
import device
import system
import system.firmware
import encoding.json
import gpio

import .config

ATHENA_VERSION ::= "v1.1.3"   // VERSION of current file

main:
  routes := {
    // Update firmware sub
    "firmware/update/$device.hardware-id.to-string": :: | topic/string payload/ByteArray |
      decoded := json.decode payload
      firmware-update "$device.hardware-id.to-string" "$decoded["token"]",
    
    "devices/$device.hardware-id.to-string/identify": :: | topic/string payload/ByteArray |
      decoded := json.decode payload
      print "[Athena] INFO: $decoded["uuid"]"
      identify-device
  }

  // Initiate client for mqtt connection
  client := mqtt.Client --host=HOST --port=BROKER-PORT --routes=routes

  // mqtt session settings for client acknowledge and authentication
  options := mqtt.SessionOptions
    --client-id = device.hardware-id.to-string
    --username  = BROKER-USER
    --password  = BROKER-PASS

  client.start --options=options
        
  print "[Athena] INFO: Connected to MQTT broker"

  task:: lifecycle client

identify-device:
  print "[Athena] INFO: Identify device"
  led-indicator := gpio.Pin ON-BOARD-LED-PIN --output
  indication-time := 0

  while indication-time < 10:
    led-indicator.set 1
    sleep --ms=250
    led-indicator.set 0
    sleep --ms=250
    indication-time += 1

init client/mqtt.Client:
  print "[Athena] INFO: Initializing device"
  
  print "[Athena] INFO: Firmware Version: $system.app-sdk-version"
  
  if firmware.is-validation-pending:
    if firmware.validate:
      print "[Athena] INFO: Firmware Update Validated"

    else:
      print "[Athena] INFO: Firmware Update Failed to Validate"

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
      print "[ATHENA] INFO: Requesting Firmware bin"
      header := Headers
      header.add "Authorization" "Bearer $token"
      response := client.get --uri="http://$HOST:$GATEWAY-PORT/firmware/download/$deviceUUID" --headers=header
      if response.status-code == 200:
        print "[ATHENA] INFO: Recived Firmware bin"
        install-firmware response.body
    finally:
      client.close
      network.close

  else:
    print "[ATHENA] WARN: UUID does not match"

install-firmware reader/io.Reader -> none:
  network := net.open
  server-socket := network.tcp-listen 1337
  print "[ATHENA] INFO: Listening on http://$network.address:$server-socket.local-address.port/"
    
  clients := []
  server := http.Server --max-tasks=5
    
  firmware-size := reader.content-size
  print "[ATHENA] INFO: Installing firmware with $firmware-size bytes"
  written-size := 0
  writer := firmware.FirmwareWriter 0 firmware-size
  led-indicator := gpio.Pin ON-BOARD-LED-PIN --output
    
  server.listen server-socket:: | request/http.RequestIncoming response-writer/http.ResponseWriter |
    web-socket := server.web-socket request response-writer
    clients.add web-socket
    try:    
        last := null
        while data := reader.read:
          led-indicator.set 1
          written-size += data.size
          writer.write data
          percent := (written-size * 100) / firmware-size
          if percent != last:
            print "[ATHENA] INFO: Installing firmware with $firmware-size bytes ($percent%)"
            clients.do: it.send "$percent"
            last = percent
            led-indicator.set 0

        writer.commit
        clients.remove web-socket
        print "[ATHENA] INFO: Installed firmware; ready to update on chip reset"
    finally:
      writer.close
      web-socket.close
      led-indicator.close

      // Wait a bit for web-socket to close
      sleep --ms=2500
      print "[ATHENA] INFO: Firmware Reboot"
      firmware.upgrade
      
      
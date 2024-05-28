import system.firmware
import system
import mqtt
import net.wifi
import device
import encoding.json

import .config

main:
  print "[Athena] INFO: Firmware Version: $system.app-sdk-version"

  if firmware.is-validation-pending:
    if firmware.validate:
      print "[Athena] INFO: Firmware Update Validated"

      // Initiate client for mqtt connection
      client := mqtt.Client --host=HOST --port=BROKER-PORT

      // mqtt session settings for client acknowledge and authentication
      options := mqtt.SessionOptions
        --client-id = device.hardware-id.to-string
        --username  = BROKER-USER
        --password  = BROKER-PASS

      print "[Athena] INFO: Connecting to broker to delete firmware folder"
      client.start --options=options

      // Create new device payload
      delete_firmware_folder := json.encode {
        "uuid": "$device.hardware-id.to-string"
      }

      // Publish the payload to the broker with specified topic
      client.publish "firmware/delete" delete_firmware_folder --qos=1 --retain=true

      client.close
      print "[Athena] INFO: Broker connection closed"

    else:
      print "[Athena] INFO: Firmware Update Failed to Validate"

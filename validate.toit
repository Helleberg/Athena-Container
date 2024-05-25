import system.firmware
import system
import net.wifi

main:
  print "Firmware Updated: $system.app-sdk-version"

  if firmware.is-validation-pending:
    if firmware.validate:
      wifi.open --ssid="RasmusHotspot" --password="150900re" --save=true
      print "firmware update validated"
    else:
      print "firmware update failed to validate"

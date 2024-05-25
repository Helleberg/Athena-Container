import system.firmware
import system
import net.wifi

main:
  print "Firmware Updated: $system.app-sdk-version"

  if firmware.is-validation-pending:
    if firmware.validate:
      wifi.open --ssid="Lindebjerg_43-2.4GHz" --password="wrpm7479" --save=true
      print "firmware update validated"
    else:
      print "firmware update failed to validate"

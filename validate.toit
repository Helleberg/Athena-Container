import system.firmware
import system

main:
  print "Firmware Updated: $system.app-sdk-version"

  if firmware.is-validation-pending:
    if firmware.validate:
      print "firmware update validated"
    else:
      print "firmware update failed to validate"

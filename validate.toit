import system.firmware
import system
import net.wifi

main:
  print "[Athena] INFO: Firmware Updated: $system.app-sdk-version"

  if firmware.is-validation-pending:
    if firmware.validate:
      print "[Athena] INFO: Firmware Update Validated"
    else:
      print "[Athena] INFO: Firmware Update Failed to Validate"

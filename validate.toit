import system.firmware
import system

main:
  print "[Athena] INFO: Firmware Version: $system.app-sdk-version"

  if firmware.is-validation-pending:
    if firmware.validate:
      print "[Athena] INFO: Firmware Update Validated"

    else:
      print "[Athena] INFO: Firmware Update Failed to Validate"

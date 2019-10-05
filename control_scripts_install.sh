#!/bin/bash
#
# tested as working 05/10/19
UDEV_LOC="/etc/udev/rules.d/"
SYSD_LOC="/etc/systemd/system/"
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
else
   cd "$(dirname "$0")"
   chmod 644 *.rules
   cp *.rules $UDEV_LOC
   udevadm control --reload-rules
   chmod 444 *.service
   cp *.service $SYSD_LOC
fi
exit 0

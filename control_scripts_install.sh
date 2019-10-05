#!/bin/bash
#
UDEV_LOC="/etc/udev/rules.d/"
SYSD_LOC="/etc/systemd/system/"
if [ whoami != root ];
  then echo "Please run as root"
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

#!/bin/bash
#
UDEV_LOC="/etc/udev/rules.d/"
if (whoami != root)
  then echo "Please run as root"
   exit 1
  else (do stuff)
   cd "$(dirname "$0")"
   chmod 644 *.rules
   cp *.rules $UDEV_LOC
   udevadm control --reload-rules
fi

exit 0

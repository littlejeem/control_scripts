#!/bin/bash
#
####################################
### THS NEEDS WORK FOR VERSION 2 ###
####################################

UDEV_LOC="/etc/udev/rules.d/"
SYSD_LOC="/etc/systemd/system/"
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
else
  chmod -R 644 udev_rules
  cp -r udev_rules/. $UDEV_LOC
  udevadm control --reload-rules
  chmod -R 444 systemd_files
  cp -r systemd_files/. $SYSD_LOC
  systemctl daemon-reload
fi
exit 0

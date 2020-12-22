#!/bin/bash
#
#
install_user=jlivin25
udev_loc="/etc/udev/rules.d/"
sysd_loc="/etc/systemd/system/"
#
#
#+----------------------+
#+---"Check for Root"---+
#+----------------------+
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi
#
#
#+-------------------------+
#+---"Set up UDEV rules"---+ <---(symlink?)
#+-------------------------+
cp -r udev_rules/. $udev_loc
if [[ $? -ne 0 ]]; then
  log_err "copying UDEV rules failed"
  exit 1
else
  log "UDEV rules copied"
fi
#modify permissions
chmod -R 644 udev_rules
if [[ $? -ne 0 ]]; then
  log_err "changing mode of UDEV files failed"
  exit 1
else
  log "changing mode of UDEV files succeded"
fi
#reload udev rules
udevadm control --reload
#
if [[ $? -ne 0 ]]; then
  log_err "Reloading UDEV rules failed"
  exit 1
else
  log "Reloading UDEV rules succeded"
fi
#
#
#+-------------------------------+
#+---"Set up SYSTEMD services"---+ <---(symlink?)
#+-------------------------------+
cp -r systemd_files/. $sysd_loc
if [[ $? -ne 0 ]]; then
  log_err "copying services to systemd failed"
  exit 1
else
  log "Services copied to systemd"
fi
#modify permissions
chmod -R 444 systemd_files
if [[ $? -ne 0 ]]; then
  log_err "changing mode of service files failed"
  exit 1
else
  log "changing mode of service files succeded"
fi
#reload udev rules
systemctl daemon-reload
#
if [[ $? -ne 0 ]]; then
  log_err "Reloading UDEV rules failed"
  exit 1
else
  log "Reloading UDEV rules succeded"
fi
#
#
#+-------------------------------+
#+---"Install ABCDE cd ripper"---+
#+-------------------------------+
if ! command -v abcde &> /dev/null
then
  log_err "abcde could not be found, script won't function wihout it, attempting install"
  apt update && apt install abcde
  if ! command -v abcde &> /dev/null
  then
    log_err "abcde install failed, scripts won't function wihout it, exiting"
    exit 1
  else
    log "abcde now installed, continuing"
  fi
else
    log "abcde command located, continuing"
fi
exit 0

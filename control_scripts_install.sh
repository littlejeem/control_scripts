#!/bin/bash
#
#
#+---------------------+
#+---"Set Variables"---+
#+---------------------+
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
#+---------------------------+
#+---"Source helper files"---+
#+---------------------------+
if [ -f "/home/"$install_user"/bin/standalone_scripts/helper_script.sh" ]; then
  source /home/"$install_user"/bin/standalone_scripts/helper_script.sh
else
  echo "help file not found exiting"
  exit 1
fi
#
#
#+-------------------------+
#+---"Set up UDEV rules"---+ <---(symlink?)
#+-------------------------+
#modify SOURCE file permissions
chmod -R 644 udev_rules
if [[ $? -ne 0 ]]; then
  log_err "changing mode of UDEV files failed"
  exit 1
else
  log "changing mode of UDEV files succeded"
fi
#copy files to dest
cp -r udev_rules/. $udev_loc
if [[ $? -ne 0 ]]; then
  log_err "copying UDEV rules failed"
  exit 1
else
  log "UDEV rules copied"
fi
#reload udev rules
udevadm control --reload
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
#modify SOURCE file permissions
chmod -R 444 systemd_files
if [[ $? -ne 0 ]]; then
  log_err "changing mode of service files failed"
  exit 1
else
  log "changing mode of service files succeded"
fi
#copy files to dest
cp -r systemd_files/. $sysd_loc
if [[ $? -ne 0 ]]; then
  log_err "copying services to systemd failed"
  exit 1
else
  log "Services copied to systemd"
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
  apt update && apt install abcde -y
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
#
#
#+--------------------------------+
#+---"Install FLAC requirement"---+
#+--------------------------------+
if ! command -v flac &> /dev/null
then
  log_err "FLAC could not be found, script won't function wihout it, attempting install"
  apt update && apt install flac -y
  if ! command -v flac &> /dev/null
  then
    log_err "FLAC install failed, scripts won't function wihout it, exiting"
    exit 1
  else
    log "FLAC now installed, continuing"
  fi
else
    log "FLAC command located, continuing"
fi


exit 0

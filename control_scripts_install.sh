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
#+-------------------+
#+---Set functions---+
#+-------------------+
helpFunction () {
   echo ""
   echo "Usage: $0 -u foo_user -d bar_drive"
   echo "Usage: $0"
   echo -e "\t Running the script with no flags causes default behaviour"
   echo -e "\t-u Use this flag to specify a user to install scripts under, eg. user foo is entered -u foo, as i made these scripts for myself the defualt user is my own"
   echo -e "\t-g Use this flag to specify a usergroup to install scripts under, eg. group bar is entered -g bar, combined with the -u flag these settings will be used as: chown foo:bar. As i made these scripts for myself the defualt group is my own"
   echo -e "\t-d Use this flag to specify the identity of the CD/DVD/BLURAY drive being used, eg. /dev/sr1 is entered -d sr1, sr0 will be the assumed default "
   exit 1 # Exit script after printing help
}
#
#
Drive_Detect () {
  cd /tmp
  if [[ $? -ne 0 ]]; then
    log_err "changing to /tmp failed, most likely this is a missing directory"
    exit 1
  else
    log_deb "changed to /tmp successfully"
  fi
  log_deb $udev_rule
  log_deb $drive_number
  log_deb $install_user
  log_deb $env_ammend
  log_deb $service_task
  drive_model=$(sudo udevadm info /dev/$drive_number | grep ID_MODEL=)
  drive_model=${drive_model:12}
  log_deb $drive_model
  udev_insert=$(echo -e "ACTION==\"change\",KERNEL==\""$drive_number"\",SUBSYSTEM==\"block\",ATTRS{model}==\""$drive_model"\",ENV{ID_CDROM_MEDIA_"$env_ammend"}==\"1\",ENV{HOME}=\"/home/"$install_user"\",RUN+=\"/bin/systemctl start "$service_task"\"")
  log_deb $udev_insert
  echo $udev_insert > $udev_rule
  #modify SOURCE file permissions
  chmod 644 $udev_rule
  if [[ $? -ne 0 ]]; then
    log_err "changing mode of UDEV $udev_rule file failed"
    exit 1
  else
    log "changing mode of UDEV $udev_rule file succeded"
  fi
  #mv files into location
  mv $udev_rule $udev_loc
  if [[ $? -ne 0 ]]; then
    log_err "moving UDEV rule $udev_rule file failed"
    exit 1
  else
    log "moving UDEV rule $udev_rule file succeded"
  fi
}
#
#
#+-----------------------+
#+---Set up user flags---+
#+-----------------------+
while getopts u:g:d:h flag
do
    case "${flag}" in
        u) user_install=${OPTARG};;
        g) group_install=${OPTARG};;
        d) drive_install=${OPTARG};;
        h) helpFunction;;
        ?) helpFunction;;
    esac
done
#
#
#+-------------------------------+
#+---Configure GETOPTS options---+
#+-------------------------------+
#user
if [[ $user_install = "" ]]; then
  install_user="jlivin25"
else
  install_user=$(echo $user_install)
fi
#group
if [[ $group_install = "" ]]; then
  install_user="jlivin25"
else
  install_group=$(echo $group_install)
fi
#drive
if [[ $drive_install = "" ]]; then
  drive_number="sr0"
else
  drive_number=$(echo $drive_install)
fi
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
  echo "$(date +%b"  "%-d" "%T)" " "INFO: helper script found, using it
  source /home/"$install_user"/bin/standalone_scripts/helper_script.sh
else
  log_err "helper file not found exiting"
  exit 1
fi
#
#
#+-------------------------+
#+---"Set up UDEV rules"---+ <---(symlink?)
#+-------------------------+
#CD
udev_rule="82-AutoCDInsert.rules"
service_task="cd_ripping.service"
env_ammend="CD" #ENV{ID_CDROM_MEDIA_CD}
Drive_Detect
#DVD
udev_rule="83-AutoDVDInsert.rules"
service_task="dvd_ripping.service"
env_ammend="DVD" #ENV{ID_CDROM_MEDIA_CD}
Drive_Detect
#BLURAY
udev_rule="84-AutoBDInsert.rules"
service_task="bd_ripping.service"
env_ammend="BD" #ENV{ID_CDROM_MEDIA_CD}
Drive_Detect
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
chmod -R 444 /home/"$install_user"/bin/control_scripts/systemd_files
if [[ $? -ne 0 ]]; then
  log_err "changing mode of service files failed"
  exit 1
else
  log "changing mode of service files succeded"
fi
#copy files to dest
cp -r /home/"$install_user"/bin/control_scripts/systemd_files/. $sysd_loc
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
#
#
if [ -d "/home/"$install_user"/.config" ]; then
  log "Located .config folder, looking for existing config.sh"
  if [ -f "/home/"$install_user"/.config/Script_Settings/config.sh" ]; then
    log "located existing config file, no further action"
  fi
else
  log_deb "No existing .config folder located at /home/$install_user/.config, creating..."
  sudo -u "$install_user" mkdir "/home/$install_user/.config"
  if [ -f "/home/"$install_user"/bin/sync_scripts/config.sh" ]; then
    log "located default config file, copying in..."
    cp "/home/"$install_user"/bin/sync_scripts/config.sh" "/home/"$install_user"/.config/"
  else
    log_err "No original or template .config folder or template located"
    exit 1
  fi
fi
log "control scripts install script completed"
exit 0

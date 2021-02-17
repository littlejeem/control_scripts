#!/bin/bash
#
##########################################################################################################
###                         THIS SCRIPT RIPS CD'S TO FLAC USING ABCDE                                  ###
### This script is kept in /home/USER/myscripts/control_scripts/ with chmod +x and 0755 or 0766 perms  ###
### This script depends on						                                                                 ###
### (1) abcde                                                                                          ###
### (2) 82-AutoCDInsert.rules which triggers                                                           ###
### (3) cd_ripping.service  which triggers this script if Audio CD is detected                         ###
### (4) https://github.com/littlejeem/abcde_configs.git to provide abcde configs                       ###
##########################################################################################################
#
#
#+-------------------+
#+---"VERSION 2.0"---+
#+-------------------+
#
#
#+---------------------------------------+
#+---"check if script already running"---+
#+---------------------------------------+
temp_dir="/tmp/CD_Ripping"
if [[ -d "$temp_dir" ]]; then
  while [[ -d "$temp_dir" ]]; do
    enotify "previous script still running"
    sleep 30; done
  else
    enotify "no previously running script detected"
fi
log_deb "temp dir is set as: $temp_dir"
mkdir "$temp_dir"
if [[ $? = 0 ]]; then
  enotify "temp directory set successfully"
else
  eerror "temp directory NOT set successfully, exiting"
  exit 1
fi
#
#
#+---------------------------------------+
#+---check if run from systemd or ROOT---+
#+---------------------------------------+
if [[ -z "${INVOCATION_ID+x}" ]]; then
  echo "no INVOCATION_ID set"
  if [[ $EUID -ne 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
  else
    echo "already running with root privaleges"
  fi
else
  echo "INVOCATION_ID is set as: $INVOCATION_ID"
  echo "Already running with root privaleges"
fi
#
#
#+-------------------+
#+---Set functions---+
#+-------------------+
function helpFunction () {
   echo ""
   echo "Usage: $0 -u ####"
   echo "Usage: $0"
   echo -e "\t Running the script with no flags causes default behaviour, user is me, drive is sr0"
   echo -e "\t Set the flags at the end of the exec line in /etc/systemd/system/cd_ripping.service"
   echo -e "\t-u Use this flag to run rip under, eg. -u foobaruser"
   echo -e "\t-d Use this flag to choose the drive to rip from, default is sr0 when not set. eg. -d sr1"
   exit 1 # Exit script after printing help
}
#
#
#+-----------------------+
#+---Set up user flags---+
#+-----------------------+
while getopts u:d:h flag
do
    case "${flag}" in
        u) user_install=${OPTARG};;
        d) drive_install=${OPTARG};;
        h) helpFunction;;
        ?) helpFunction;;
    esac
done
#
#
#+-------------------------+
#+---Configure user name---+
#+-------------------------+
if [[ $user_install == "" ]]; then
  install_user="$USER"
else
  install_user=$(echo $user_install)
fi
#
#
#+--------------------------+
#+---Configure drive used---+
#+--------------------------+
if [[ $drive_install == "" ]]; then
  install_drive=sr0
else
  install_drive=$(echo $drive_install)
fi
#
#
#+---------------------+
#+---"Set Variables"---+
#+---------------------+
PATH=/sbin:/bin:/usr/bin:/home/"$install_user":/home/"$install_user"/.local/bin:/home/"$install_user"/bin
#
#
#+-------------------+
#+---Source helper---+
#+-------------------+
source /home/$install_user/bin/standalone_scripts/helper_script.sh
source /home/$install_user/.config/ScriptSettings/sync_config.sh
#
#
#+----------------------+
#+---Define Functions---+
#+----------------------+
ripcd_flac () {
  abcde -j `getconf _NPROCESSORS_ONLN` -N -c /home/"$install_user"/.config/ScriptSettings/abcde_flac.conf -d /dev/"$drive_install"
}
#
#
#+----------------------+
#+---Set Up Variables---+
#+----------------------+
timestamp=$(date +%a%R)
export "$timestamp" #<---Export so that abcde appends to folder name so that each 'unknown artist' has a time attached
log_deb "exported timestamp as $timestamp"
export "$install_user" #<---Used when 'munging' names, used in abcde.conf
export "$install_group" #<---Used when 'munging' names, used in abcde.conf
#
OUTPUTDIR=$(echo $rip_flac) #<---Export so that abcde can use in its conf
export $OUTPUTDIR
log_deb "exported $rip_flac to OUTPUTDIR $OUTPUTDIR for abcde use"
#
#
#+------------------+
#+---Start Script---+
#+------------------+
enotify "Script Started"
enotify "Stage 1 - FLAC Ripping Started"
cd $rip_flac
ripcd_flac
if [[ $? -ne 1 ]]; then
  enotify "Successfully ripped cd completed with no errors"
else
  eerror "ripd_flac function failed with an error, check logs. cd NOT ripped"
  exit 1
fi
enotify "Stage 2 - FLAC Ripping Completed"
enotify "Stage 3 - Calling MusicSync to process files"
sudo -u $install_user /home/"$install_user"/bin/sync_scripts/MusicSync.sh # <----------SWITCH TO VARIABLE IN CONFIG?...as in ON, OFF?
if [[ $? -ne 1 ]]; then
  enotify "MusicSync completed with no errors"
else
  eerror "MusicSync failed with an error, check logs"
  exit 1
fi
enotify "Stage 4 - Ejecting CD"
eject /dev/$drive_install
if [[ $? -ne 1 ]]; then
  enotify "Ejected drive successfully"
else
  eerror "Drive failed to eject, check logs. Rest of script completed"
  exit 1
fi
#
rm -r $temp_dir
exit 0

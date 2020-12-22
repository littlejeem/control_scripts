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
#+----------------+
#+---check ROOT---+
#+----------------+
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
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
   echo -e "\t Running the script with no flags causes default behaviour"
   echo -e "\t-u Use this flag to specify a user to install jackett under"
   exit 1 # Exit script after printing help
}
#
#
#+-----------------------+
#+---Set up user flags---+
#+-----------------------+
while getopts u:h flag
do
    case "${flag}" in
        u) user_install=${OPTARG};;
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
  install_user=jlivin25
else
  install_user=$(echo $user_install)
fi
#
#
#+-------------------+
#+---Source helper---+
#+-------------------+
source /home/"$install_user"/bin/standalone_scripts/helper_script.sh
source /home/"$install_user"/bin/.config/ScriptSettings/sync_config.sh
#
#
#+---------------------+
#+---"Set Variables"---+
#+---------------------+
PATH=/sbin:/bin:/usr/bin:/home/"$install_user":/home/"$install_user"/.local/bin:/home/"$install_user"/bin
#
#
#+----------------------+
#+---Define Functions---+
#+----------------------+
ripcd_flac () {
  abcde -j `getconf _NPROCESSORS_ONLN` -N -c /home/$install_user/bin/control_scripts/abcde_configs/abcde_flac.conf
}
#
#
#+------------------+
#+---Start Script---+
#+------------------+
log "----------------------------------------------------"
log "Script Started"
log "Stage 1 - FLAC Ripping Started"
cd $rip_flac
ripcd_flac
log "Stage 2 - FLAC Ripping Completed"
log "Stage 3 - Syncing Rip to Library"
sudo -u /home/$install_user/bin/myscripts/MusicSync.sh # <----------SWITCH TO VARIABLE IN CONFIG?
eject
log "Stage 4 - Complete - CD Ejected, End of Script"
#
exit 0

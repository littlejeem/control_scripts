#!/bin/bash
#
##########################################################################################################
###                         THIS SCRIPT RIPS CD'S TO FLAC USING ABCDE                                  ###
### This script is kept in /home/USER/myscripts/control_scripts/ with chmod +x and 0755 or 0766 perms  ###
### This script depends on						                                                                 ###
### (1) abcde                                                                                          ###
### (2) 82-AutoCDInsert.rules which triggers                                                           ###
### (3) cd_ripping.service  which triggers this script if Audio CD is detected                         ###
##########################################################################################################
#
#
#####################
### SET VARIABLES ###
#####################
locknamelong=`basename "$0"`                      # imports the name of this script
lockname=${locknamelong::-3}                      # reduces the name to remove .sh
logfolder=/home/jlivin25/bin/myscripts/scriptlogs # Where the logs are kept
lognameCDRipping=$lockname.log                    # Uses the script name to create the log
INALACPATH=/home/jlivin25/Music/m4a               # m4a
INFLACPATH=/home/jlivin25/Music/flac              #
OUTALACPATH=/media/Data_1/Music/correct/Albums    #
OUTFLACPATH=/media/Data_1/Music/FLAC_Backups      #
#
#
########################
### DEFINE FUNCTIONS ###
########################
ripcd_flac () {
abcde -j `getconf _NPROCESSORS_ONLN` -N -c /home/jlivin25/bin/myscripts/abcde_configs/abcde_flac.conf
}
#
#
####################
### START SCRIPT ###
####################
echo "----------------------------------------------------" >> $logfolder/$lognameCDRipping
echo "`date +%d/%m/%Y` - `date +%H:%M:%S` - Script Started" >> $logfolder/$lognameCDRipping
#
echo "`date +%d/%m/%Y` - `date +%H:%M:%S` - Stage 1 - FLAC Ripping Started" >> $logfolder/$lognameCDRipping
cd /home/jlivin25/Music/RipTransfers
ripcd_flac
echo "`date +%d/%m/%Y` - `date +%H:%M:%S` - Stage 2 - FLAC Ripping Completed" >> $logfolder/$lognameCDRipping
#
echo "`date +%d/%m/%Y` - `date +%H:%M:%S` - Stage 3 - Syncing Rip to Library" >> $logfolder/$lognameCDRipping
#sudo -u jlivin25 /home/jlivin25/bin/myscripts/MusicSync.sh
eject
echo "`date +%d/%m/%Y` - `date +%H:%M:%S` - Stage 4 - Complete - CD Ejected, End of Script" >> $logfolder/$lognameCDRipping
#
exit 0
#
#
#####################
### END OF SCRIPT ###
#####################

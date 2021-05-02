#!/bin/bash
#
#
#+---------------------+
#+---"Set Variables"---+
#+---------------------+
udev_loc="/etc/udev/rules.d/"
sysd_loc="/etc/systemd/system/"
#set default logging level
verbosity=3
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
    eerror "changing to /tmp failed, most likely this is a missing directory"
    exit 1
  else
    edebug "changed to /tmp successfully"
  fi
  edebug "$udev_rule"
  edebug "$drive_number"
  edebug "$install_user"
  edebug "$env_ammend"
  #drive_model=$(sudo udevadm info /dev/$drive_number | grep ID_MODEL=)
  drive_model=$(udevadm info -a -n /dev/$drive_number | grep -o 'ATTRS{model}=="[^"]*"')
  #ATTRS{model}=="BD-CMB UJ160    "
  edebug "$drive_model"
  udev_insert='ACTION=="change",KERNEL=="'"$drive_number"'",SUBSYSTEM=="block",'"$drive_model"',ENV{ID_CDROM_MEDIA_'"$env_ammend"'}=="1",ENV{HOME}="/home/'"$install_user"'",RUN+="/bin/systemctl start '"${env_ammend}"'_ripping.service"'
  edebug "$udev_insert"
  echo "$udev_insert" > $udev_rule
  #modify SOURCE file permissions
  chmod 644 $udev_rule
  if [[ $? -ne 0 ]]; then
    eerror "changing mode of UDEV $udev_rule file failed"
    exit 1
  else
    enotify "changing mode of UDEV $udev_rule file succeded"
  fi
  #mv files into location
  mv $udev_rule $udev_loc
  if [[ $? -ne 0 ]]; then
    eerror "moving UDEV rule $udev_rule file failed"
    exit 1
  else
    enotify "moving UDEV rule $udev_rule file succeded"
  fi
}
#
#
systemd_service_create () {
cat > /etc/systemd/system/${env_ammend}_ripping.service <<EOF

[Unit]
Description=${env_ammend} Ripping Service

[Service]
SyslogIdentifier=${env_ammend}_ripping_service
Type=simple
User=$install_user
ExecStart=/home/$install_user/bin/control_scripts/ripping_scripts/${env_ammend}_ripping.sh -u $install_user -d $drive_number
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF
}
#
#
abcde_conf_create () {
cat > /home/"$install_user"/.config/ScriptSettings/abcde_flac.conf << 'EOF'
LOWDISK=n
INTERACTIVE=n
CDDBMETHOD=cddb
#
#+-------------------+
#+---Source Config---+
#+-------------------+
GLYRC=glyrc
GLYRCOPTS=

IDENTIFY=identify
IDENTIFYOPTS=

DISPLAYCMD=display
DISPLAYCMDOPTS="-resize 512x512 -title abcde_album_art"

CONVERT=convert
CONVERTOPTS=

ALBUMARTALWAYSCONVERT="n"

ALBUMARTFILE="folder.jpg"
ALBUMARTTYPE="JPEG"
#----------------------------------------------------------------#
CDDBCOPYLOCAL="n"
CDDBLOCALDIR="$HOME/.cddb"
CDDBLOCALRECURSIVE="y"
CDDBUSELOCAL="n"

FLACENCODERSYNTAX=flac

FLAC=flac

FLACOPTS='--verify --best'

OUTPUTTYPE="flac"

CDROMREADERSYNTAX=cdparanoia

CDPARANOIA=cdparanoia
CDPARANOIAOPTS="--never-skip=40"

CDDISCID=cd-discid

#OUTPUTDIR= #<--- Now pulled from CD_Ripping.sh

ACTIONS=read,encode,move,clean

# Decide here how you want the tracks labelled for a standard 'single-artist',
# multi-track encode and also for a multi-track, 'various-artist' encode:
OUTPUTFORMAT='${ARTISTFILE}/${ALBUMFILE}/${TRACKNUM} - ${TRACKFILE} - ${ARTISTFILE}'
VAOUTPUTFORMAT='Various/${ALBUMFILE}/${TRACKNUM} - ${TRACKFILE} - ${ARTISTFILE}'

# single-track encode and also for a single-track 'various-artist' encode.
# (Create a single-track encode with 'abcde -1' from the commandline.)
ONETRACKOUTPUTFORMAT='${ARTISTFILE}-${ALBUMFILE}/${ALBUMFILE}'
VAONETRACKOUTPUTFORMAT='Various/${ALBUMFILE}/${ALBUMFILE}'

# This function takes out dots preceding the album name, and removes a grab
# bag of illegal characters. It allows spaces, if you do not wish spaces add
# in -e 's/ /_/g' after the first sed command.
mungefilename ()
{
  echo "$@" | sed -e 's/^\.*//' | tr -d ":><|*/\"'?[:cntrl:]"
}

# What extra options?
MAXPROCS=6                              # Run a few encoders simultaneously
PADTRACKS=y                             # Makes tracks 01 02 not 1 2
EXTRAVERBOSE=2                          # Useful for debugging
COMMENT='abcde version 2.7.2'           # Place a comment...
EJECTCD=n                              # Please eject cd when finished :-)

post_encode ()
{
ARTISTFILE="$(mungefilename "$TRACKARTIST")"
ALBUMFILE="$(mungefilename "$DALBUM")"
GENRE="$(mungegenre "$GENRE")"
YEAR=${CDYEAR:-$CDYEAR}

if [ "$VARIOUSARTISTS" = "y" ] ; then
FINDPATH="$(eval echo "$VAOUTPUTFORMAT")"
else
FINDPATH="$(eval echo "$OUTPUTFORMAT")"
fi

FINALDIR="$(dirname "$OUTPUTDIR")"
FINALDIR1="$(dirname "$OUTPUTDIR")"
C_CMD=(chown -R ${install_user}:${install_group} "$FINALDIR")
C_CMD1=(chmod -R 777 "$FINALDIR")
#echo "${C_CMD[@]}" >> tmp2.log
"${C_CMD[@]}"
"${C_CMD1[@]}"
cd "$FINALDIR"

if [ "$OUTPUTTYPE" = "flac" ] ; then
vecho "Preparing to embed the album art..." >&2
else
vecho "Not embedding album art, you need flac output.." >&2
return 1
fi
}
EOF
if [[ $? -ne 1 ]]; then
  enotify "abcde_flac.conf created successfully at /home/"$install_user"/.config/ScriptSettings/"
else
  eerror "abcde_flac.conf not able to be created, exiting"
  exit 1
fi
chown $install_user:$install_user /home/"$install_user"/.config/ScriptSettings/abcde_flac.conf
if [[ $? -ne 1 ]]; then
  enotify "successfully chown'd /home/"$install_user"/.config/ScriptSettings/abcde_flac.conf"
else
  eerror "chown'ing /home/"$install_user"/.config/ScriptSettings/abcde_flac.conf failed, exiting"
  exit 1
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
  export install_user="jlivin25"
else
  export install_user=$(echo $user_install)
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
#+---------------------------+
#+---"Source helper files"---+
#+---------------------------+
if [ -f /usr/local/bin/helper_script.sh ]; then
  echo "$(date +%b"  "%-d" "%T)" " "INFO: helper script found, using it
  source /usr/local/bin/helper_script.sh
else
  echo "$(date +%b"  "%-d" "%T)" " "ERROR: helper file not found exiting
  exit 1
fi
#
#
#+----------------------+
#+---"Check for Root"---+
#+----------------------+
edebug env
enotify "INVOCATION_ID is set as: $INVOCATION_ID"
enotify "EUID is set as: $EUID"
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi
#
#
#+-------------------------+
#+---"Set up UDEV rules"---+ <---(symlink?)
#+-------------------------+
enotify "setting up UDEV rules & SYSTEMD services"
#CD
udev_rule="82-AutoCDInsert.rules"
env_ammend="CD" #ENV{ID_CDROM_MEDIA_CD}
Drive_Detect
systemd_service_create
#DVD
udev_rule="83-AutoDVDInsert.rules"
env_ammend="DVD" #ENV{ID_CDROM_MEDIA_DVD}
Drive_Detect
systemd_service_create
#BLURAY
udev_rule="84-AutoBDInsert.rules"
env_ammend="BD" #ENV{ID_CDROM_MEDIA_BD}
Drive_Detect
systemd_service_create
#
enotify "created UDEV & SYSTEMD files"
#
#reload udev rules
enotify "reloading UDEV rules"
udevadm control --reload
if [[ $? -ne 0 ]]; then
  eerror "Reloading UDEV rules failed"
  exit 1
else
  enotify "Reloading UDEV rules succeded"
fi
#reload systemd services
systemctl daemon-reload
if [[ $? -ne 0 ]]; then
  eerror "Reloading .service files failed"
  exit 1
else
  enotify "Reloading .service files succeded"
fi
#
#
#+-------------------------------+
#+---"Install ABCDE cd ripper"---+
#+-------------------------------+
if ! command -v abcde &> /dev/null
then
  eerror "abcde could not be found, script won't function wihout it, attempting install"
  apt update && apt install abcde -y
  if ! command -v abcde &> /dev/null
  then
    eerror "abcde install failed, scripts won't function wihout it, exiting"
    exit 1
  else
    enotify "abcde now installed, continuing"
  fi
else
    enotify "abcde command located, continuing"
fi
#
#
#+--------------------------------+
#+---"Install FLAC requirement"---+
#+--------------------------------+
if ! command -v flac &> /dev/null
then
  eerror "FLAC could not be found, script won't function wihout it, attempting install"
  apt update && apt install flac -y
  if ! command -v flac &> /dev/null
  then
    eerror "FLAC install failed, scripts won't function wihout it, exiting"
    exit 1
  else
    enotify "FLAC now installed, continuing"
  fi
else
    enotify "FLAC command located, continuing"
fi
#
#
if [ -d "/home/"$install_user"/.config" ]; then
  enotify "Located .config folder, looking for existing sync_config.sh"
  if [ -f "/home/"$install_user"/.config/ScriptSettings/sync_config.sh" ]; then
    enotify "located existing sync_config file, using..."
    source /home/"$install_user"/.config/ScriptSettings/sync_config.sh
    #+-------------------------------------+
    #+---"Check necessary folders exist"---+
    #+-------------------------------------+
    #rip dest
    if [ -d "$rip_flac" ]; then
      enotify "rip destination already exists, using"
    else
      edebug "rip destination doesn't exist, creating"
      sudo -u $install_user mkdir -p $rip_flac
      if [[ $? -ne 1 ]]; then
        if [ -d "$rip_flac" ]; then
          enotify "rip destination created successfully at $rip_flac"
        fi
      else
        eerror "rip destination not able to be created, exiting"
        exit 1
      fi
    fi
    #flac dest
    if [ -d "$FLAC_musicdest" ]; then
      enotify "flac music destination already exists, using"
    else
      edebug "flac music destination doesn't exist, creating"
      sudo -u $install_user mkdir -p $FLAC_musicdest
      if [[ $? -ne 1 ]]; then
        if [ -d "$FLAC_musicdest" ]; then
          enotify "flac music destination created successfully at $FLAC_musicdest"
        fi
      else
        eerror "flac music destination not able to be created, exiting"
        exit 1
      fi
      chown -R $user_install:$group_install $FLAC_musicdest
      if [[ $? -ne 1 ]]; then
        enotify "successfully chmod'ed directory $FLAC_musicdest"
      else
        eerror "chmod'ing directory; $FLAC_musicdest failed, exiting"
        exit 1
      fi
    fi
    #alac dest
    if [ -d "$M4A_musicdest" ]; then
      enotify "M4A music destination already exists, using"
    else
      edebug "M4A music destination doesn't exist, creating"
      sudo -u $install_user mkdir -p $M4A_musicdest
      if [[ $? -ne 1 ]]; then
        if [ -d "$M4A_musicdest" ]; then
          enotify "M4A music destination created successfully at $M4A_musicdest"
        fi
      else
        eerror "M4A music destination not able to be created, exiting"
        exit 1
      fi
    fi
  #beets configs
  if [ -d "$beets_flac_path" ]; then #<----make this an AND comparison??
    enotify "beets config folder exists, using"
  else
    edebug "beets config folder(s) doen't exist, creating"
    sudo -u $install_user mkdir -p $beets_flac_path
    sudo -u $install_user mkdir -p $beets_alac_path
    sudo -u $install_user mkdir -p $beets_upload_path
    if [[ $? -ne 1 ]]; then
      if [ -d "$beets_flac_path" ]; then
        enotify "beets config folder(s) created successfully at $beets_flac_path, $beets_alac_path, $beets_upload_path"
      fi
    else
      eerror "beets config folder(s) not able to be created, exiting"
      exit 1
    fi
#    chown -R $user_install:$group_install $beets_flac_path
#    chown -R $user_install:$group_install $beets_alac_path
#    chown -R $user_install:$group_install $beets_upload_path
#    if [[ $? -ne 1 ]]; then
#      enotify "successfully chmod'ed directory $beets_flac_path, $beets_alac_path, $beets_upload_path"
#    else
#      eerror "chmod'ing beets config folder(s) failed, exiting"
#      exit 1
#    fi
  fi
  else
    eerror "No existing sync_config file found, error?"
  fi
else
  edebug "No existing .config folder located at /home/$install_user/.config, creating..."
  sudo -u "$install_user" mkdir "/home/$install_user/.config/ScriptSettings"
  if [ -f "/home/"$install_user"/bin/sync_scripts/config.sh" ]; then
    enotify "located default config file, copying in..."
    cp "/home/"$install_user"/bin/sync_scripts/config.sh" "/home/"$install_user"/.config/ScriptSettings/sync_config.sh"
    enotify "Please now set up required conditions, locations and options in /home/"$install_user"/.config/ScriptSettings/sync_config.sh and re-run this script"
  else
    eerror "No original or template .config folder or template located"
    exit 1
  fi
fi
abcde_conf_create
#
#
enotify "control scripts install script completed"
exit 0

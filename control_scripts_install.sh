#!/usr/bin/env bash
#
############################################################################################################
###                                                 "INFO"                                               ###
### A sript to automate the necessary steps to install control_scripts, put items in necessary locations ###
### for the first time running of scripts in other repository's such as sync_scripts/MusicSync.sh        ###
### Its vital that the locations have
############################################################################################################
#
#+--------------------------------------+
#+---"Exit Codes & Logging Verbosity"---+
#+--------------------------------------+
# pick from 64 - 113 (https://tldp.org/LDP/abs/html/exitcodes.html#FTN.AEN23647)
# exit 0 = Success
# exit 64 = Variable Error
# exit 65 = Sourcing file/folder error
# exit 66 = Processing Error
# exit 67 = Required Program Missing
#
#verbosity levels
#silent_lvl=0
#crt_lvl=1
#err_lvl=2
#wrn_lvl=3
#ntf_lvl=4
#inf_lvl=5
#dbg_lvl=6
#
#
#+------------------------------+
#+---"Set Special Parameters"---+
#+------------------------------+
#-u Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error when performing parameter expansion. An error message will be written to the standard error, and a non-interactive shell will exit.
#set -u
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
#+-----------------------+
#+---"Set script name"---+
#+-----------------------+
# imports the name of this script
# failure to to set this as lockname will result in check_running failing and 'hung' script
# manually set this if being run as child from another script otherwise will inherit name of calling/parent script
scriptlong=`basename "$0"`
lockname=${scriptlong::-3} # reduces the name to remove .sh
#
#
#
#
#+--------------------------+
#+---Source helper script---+
#+--------------------------+
source /usr/local/bin/helper_script.sh
#
#
#+---------------------+
#+---"Set Variables"---+
#+---------------------+
udev_loc="/etc/udev/rules.d/"
sysd_loc="/etc/systemd/system/"
#set default logging level
verbosity=3
version=0.4
#
#
#+---------------------------------------+
#+---"check if script already running"---+
#+---------------------------------------+
check_running
#
#
#+-------------------+
#+---Set functions---+
#+-------------------+
helpFunction () {
   echo ""
   echo "Usage: $0 $scriptlong"
   echo "Usage: $0 -V selects dry-run with verbose level logging"
   echo -e "\t-d Use this flag to specify dry run, no files will be converted, useful in conjunction with -V or -G "
   echo -e "\t-S Override set verbosity to specify silent log level"
   echo -e "\t-V Override set verbosity to specify Verbose log level"
   echo -e "\t-G Override set verbosity to specify Debug log level"
   echo -e "\t-p Specifically choose to install postfix prior to attempting to install abcde as its a requirement"
   echo -e "\t-u Use this flag to specify a user to install scripts under, eg. user foo is entered -u foo, as i made these scripts for myself the defualt user is my own"
   echo -e "\t-g Use this flag to specify a usergroup to install scripts under, eg. group bar is entered -g bar, combined with the -u flag these settings will be used as: chown foo:bar. As i made these scripts for myself the defualt group is my own"
   echo -e "\t-d Use this flag to specify the identity of the CD/DVD/BLURAY drive being used, eg. /dev/sr1 is entered -d sr1, sr0 will be the assumed default "
   echo -e "\t Running the script with no flags causes default behaviour with logging level set via 'verbosity' variable"
   echo -e "\t-h -H Use this flag for help"
   if [ -d "/tmp/$lockname" ]; then
     edebug "removing lock directory"
     rm -r "/tmp/$lockname"
   else
     edebug "problem removing lock directory"
   fi
   exit 65 # Exit script after printing help
}
#
#
drive_detect () {
  cd /tmp
  if [[ $? -ne 0 ]]; then
    eerror "changing to /tmp failed, most likely this is a missing directory"
    exit 66
  else
    edebug "changed to /tmp successfully"
  fi
  edebug "udev_rule set as: $udev_rule"
  edebug "drive number set as: $drive_number"
  edebug "install user being used: $install_user"
  edebug "env_ammend is set as: $env_ammend"
  #drive_model=$(sudo udevadm info /dev/$drive_number | grep ID_MODEL=)
  drive_model=$(udevadm info -a -n /dev/$drive_number | grep -o 'ATTRS{model}=="[^"]*"')
  #example of return is: ATTRS{model}=="BD-CMB UJ160    "
  #for testing with no drive hooked up, eg on VM_Machine uncomment this next line
  #drive_model=ATTRS{model}=="BD-CMB UJ160    "
  edebug "$drive_model"
  udev_insert='ACTION=="change",KERNEL=="'"$drive_number"'",SUBSYSTEM=="block",'"$drive_model"',ENV{ID_CDROM_MEDIA_'"$env_ammend"'}=="1",ENV{HOME}="/home/'"$install_user"'",RUN+="/bin/systemctl start '"${env_ammend}"'_ripping.service"'
  edebug "$udev_insert"
  echo "$udev_insert" > $udev_rule
  #modify SOURCE file permissions
  chmod 644 $udev_rule
  if [[ $? -ne 0 ]]; then
    eerror "changing mode of UDEV $udev_rule file failed"
    exit 66
  else
    enotify "changing mode of UDEV $udev_rule file succeded"
  fi
  #mv files into location
  mv $udev_rule $udev_loc
  if [[ $? -ne 0 ]]; then
    eerror "moving UDEV rule $udev_rule file failed"
    exit 66
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
cat > "$abcde_loc"/abcde_flac.conf << 'EOF'
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
C_CMD1=(chmod -R 775 "$FINALDIR")
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
  enotify "abcde_flac.conf created successfully at "$abcde_loc""
else
  eerror "abcde_flac.conf not able to be created, exiting"
  exit 66
fi
chown $install_user:$install_user "$abcde_loc"/abcde_flac.conf
if [[ $? -ne 1 ]]; then
  enotify "successfully chown'd $abcde_loc/abcde_flac.conf"
else
  eerror "chown'ing $abcde_loc/abcde_flac.conf failed, exiting"
  exit 66
fi
}
#
# make the folder_check var equal to the folder variable to search for, eg: folder_check=$alaclibrary_source
check_folder () {
  if [[ -d "$folder_check" ]]; then
    enotify "$folder_check source already exists, using"
  else
    edebug "$folder_check source doesn't exist, creating"
    sudo -u "$install_user" mkdir -p "$folder_check"
    if [[ $? -ne 1 ]]; then
      if [[ -d "$folder_check" ]]; then
        enotify "$folder_check source created successfully"
      fi
    else
      eerror "$folder_check source not able to be created, exiting"
      exit 65
    fi
  fi
}
#
#+------------------------+
#+---"Get User Options"---+
#+------------------------+
while getopts ":SVGHhpu:g:d:" opt
do
    case "${opt}" in
        S) verbosity=$silent_lvl
        edebug "-S specified: Silent mode";;
        V) verbosity=$inf_lvl
        edebug "-V specified: Verbose mode";;
        G) verbosity=$dbg_lvl
        edebug "-G specified: Debug mode";;
        p) post_fix_install=1
        edebug "-p specified: installing postfix defaults";;
        u) user_install=${OPTARG}
        edebug "-u specified: User set as: $user_install";;
        g) group_install=${OPTARG}
        edebug "-g specified: Group set as: $group_install";;
        d) drive_install=${OPTARG}
        edebug "-d specified: optical drive set as: $drive_install";;
        H) helpFunction;;
        h) helpFunction;;
        ?) helpFunction;;
    esac
done
#
#
#+-------------------------------+
#+---Configure GETOPTS options---+
#+-------------------------------+
esilent "control_scripts_install.sh started"
#user
if [[ -z $user_install ]]; then
  install_user="jlivin25"
  export install_user
else
  install_user=$(echo $user_install)
  export install_user=$(echo $user_install)
fi
edebug "Using $install_user as install user"
#group
if [[ -z $group_install ]]; then
  install_group="jlivin25"
else
  install_group=$(echo $group_install)
fi
edebug "install group set as: $install_group"
#drive
if [[ -z $drive_install ]]; then
  drive_number="sr0"
  edebug "no alternative drive specified, using default: $drive_number as drive install"
else
  drive_number=$(echo $drive_install)
  edebug "alternative drive specified, using: $drive_number as drive install"
fi
#
edebug "GETOPTS options set"
#
#
#+-------------------+
#+---Set up script---+
#+-------------------+
#Get environmental info
#enotify "INVOCATION_ID is set as: $INVOCATION_ID"
enotify "EUID is set as: $EUID"
edebug "PATH is: $PATH"
#Grab PID
script_pid=$(echo $$)
edebug "control_scripts_install.sh PID is: $script_pid"
#display version
edebug "Version is: $version"
#
#
#+-------------------------+
#+---"Set up UDEV rules"---+ <---(symlink?)
#+-------------------------+
enotify "setting up UDEV rules & SYSTEMD services"
#CD
udev_rule="82-AutoCDInsert.rules"
env_ammend="CD" #ENV{ID_CDROM_MEDIA_CD}
drive_detect
systemd_service_create
#DVD
udev_rule="83-AutoDVDInsert.rules"
env_ammend="DVD" #ENV{ID_CDROM_MEDIA_DVD}
drive_detect
systemd_service_create
#BLURAY
udev_rule="84-AutoBDInsert.rules"
env_ammend="BD" #ENV{ID_CDROM_MEDIA_BD}
drive_detect
systemd_service_create
#
enotify "created UDEV & SYSTEMD files"
#
#reload udev rules
enotify "reloading UDEV rules"
udevadm control --reload
if [[ $? -ne 0 ]]; then
  eerror "Reloading UDEV rules failed"
  exit 66
else
  enotify "Reloading UDEV rules succeded"
fi
#reload systemd services
systemctl daemon-reload
if [[ $? -ne 0 ]]; then
  eerror "Reloading .service files failed"
  exit 66
else
  enotify "Reloading .service files succeded"
fi
#
#
#+--------------------------------------------+
#+---"Check for necessary programs / tools"---+
#+--------------------------------------------+
#post fix if opted for
if [[ ! -v $post_fix_install ]]; then
  edebug "post_fix install chosen, installing"
  debconf-set-selections <<< "postfix postfix/mailname string $hostname"
  debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Local only'"
  DEBIAN_FRONTEND=noninteractive apt-get install -qq --assume-yes postfix < /dev/null > /dev/null
fi
#abcde
program_check="abcde"
prog_check
#
#flac
program_check="flac"
prog_check
#
#
#+---------------------------------------------+
#+---"Check necessary folders / files exist"---+
#+---------------------------------------------+
if [ -f "/usr/local/bin/config.sh" ]; then
  enotify "located existing sync_config file, using..."
  source /usr/local/bin/config.sh
  #config file $alaclibrary_source ; Beets library location where the FLAC files are converted to M4A and placed
  folder_check=$alaclibrary_source
  check_folder
  #
  #flaclibrary_source="/home/jlivin25/Music/Library/flacimports/" #Beets library location where the FLAC files are tagged and moved too
  folder_check=$flaclibrary_source
  check_folder
  #
  #upload_mp3="/home/jlivin25/Music/Library/PlayUploads/"
  folder_check=$upload_mp3
  check_folder
  #
  #RIP dest
  folder_check=$rip_flac
  check_folder
  #
  #FLAC dest
  folder_check=$FLAC_musicdest
  check_folder
  chown -R "$user_install":"$group_install" "$folder_check"
  if [[ $? -ne 1 ]]; then
    enotify "successfully chmod'ed directory $folder_check"
  else
    eerror "chmod'ing directory; $folder_check failed, exiting"
    exit 65
  fi
  #ALAC dest
  folder_check=$M4A_musicdest
  check_folder
  #
  #beets config section
  #
  #beets FLAC config location
  folder_check=$beets_flac_path
  check_folder
  #
  #beets ALAC config location
  folder_check=$beets_alac_path
  check_folder
  #
  #beets UPLOAD config location
  folder_check=$beets_upload_path
  check_folder
  #
  #
  if [ -d "$beets_flac_path" ] && [ -d "$beets_alac_path" ] && [ -d "$beets_upload_path" ]; then
    enotify "beets config folder(s) created successfully at $beets_flac_path, $beets_alac_path, $beets_upload_path"
  else
    eerror "error in creating beets config folder(s) not able to be created, exiting"
    exit 65
  fi
  #
  #BEETS CONFIG FILES
  #beets_flac_path="/home/$install_user/.config/beets/flac" #path to beets config & library file directory (FLAC), do not include a file name
  if [ -d "$beets_flac_path" ]; then
    enotify "FLAC beets config directory already exists, using"
    if [ -d "/home/$install_user/bin/control_scripts/beets_configs" ]; then
      sudo -u $install_user cp /home/$install_user/bin/control_scripts/beets_configs/flac_config.yaml $beets_flac_path
    fi
  else
    edebug "FLAC beets config directory doesn't exist, creating"
    sudo -u $beets_flac_path mkdir -p $M4A_musicdest
    if [[ $? -ne 1 ]]; then
      if [ -d "$beets_flac_path" ]; then
        edebug "FLAC beets config directory created successfully at $beets_flac_path"
        if [ -d "/home/$install_user/bin/control_scripts/beets_configs" ]; then
          sudo -u $install_user cp /home/$install_user/bin/control_scripts/beets_configs/flac_config.yaml $beets_flac_path
        fi
      fi
    else
      eerror "FLAC beets config directory not able to be created, exiting"
      exit 65
    fi
  fi
  #
  #beets_alac_path="/home/$install_user/.config/beets/alac" #path to beets config & library file directory (alac), do not include a file name
  if [ -d "$beets_alac_path" ]; then
    enotify "ALAC beets config directory already exists, using"
    if [ -d "/home/$install_user/bin/control_scripts/beets_configs" ]; then
      sudo -u $install_user cp /home/$install_user/bin/control_scripts/beets_configs/flac_config.yaml $beets_alac_path
    fi
  else
    edebug "FLAC beets config directory doesn't exist, creating"
    sudo -u $beets_alac_path mkdir -p $M4A_musicdest
    if [[ $? -ne 1 ]]; then
      if [ -d "$beets_alac_path" ]; then
        edebug "FLAC beets config directory created successfully at $beets_alac_path"
        if [ -d "/home/$install_user/bin/control_scripts/beets_configs" ]; then
          sudo -u $install_user cp /home/$install_user/bin/control_scripts/beets_configs/alac_config.yaml $beets_alac_path
        fi
      fi
    else
      eerror "FLAC beets config directory not able to be created, exiting"
      exit 65
    fi
  fi
  #
  #beets_upload_path="/home/$install_user/.config/beets/uploads" #path to beets config & library file directory (upload), do not include a file name
  if [ -d "$beets_upload_path" ]; then
    enotify "UPLOAD beets config directory already exists, using"
    if [ -d "/home/$install_user/bin/control_scripts/beets_configs" ]; then
      sudo -u $install_user cp /home/$install_user/bin/control_scripts/beets_configs/flac_config.yaml $beets_upload_path
    fi
  else
    edebug "FLAC beets config directory doesn't exist, creating"
    sudo -u $install_user mkdir -p $beets_upload_path
    if [[ $? -ne 1 ]]; then
      if [ -d "$beets_upload_path" ]; then
        edebug "FLAC beets config directory created successfully at $beets_upload_path"
        if [ -d "/home/$install_user/bin/control_scripts/beets_configs" ]; then
          sudo -u $install_user cp /home/$install_user/bin/control_scripts/beets_configs/alac_config.yaml $beets_upload_path
        fi
      fi
    else
      eerror "FLAC beets config directory not able to be created, exiting"
      exit 65
    fi
  fi
else
  eerror "No existing sync_config file found, error?"
fi
#
#add
echo PATH="$PATH:/home/$install_user/.local/bin" >> /home/$install_user/.bashrc
#
#create abcde conf location
if [[ ! -z "$abcde_loc" ]]; then
  if [[ -d $abcde_loc ]]; then
    edebug "abcde location already exists"
  else
    edebug "abcde location given, creating"
    sudo -u $install_user mkdir -p "$abcde_loc"
    if [[ $? -ne 0 ]]; then
      eerror "not able to create abcde location"
      exit 66
    fi
  fi
fi
#create abcde conf
if [[ ! -z "$abcde_loc" ]]; then
  abcde_conf_create
fi
#Install main beets app
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null
program_check="python-dev"
DEBIAN_FRONTEND=noninteractive apt-get install -qq "$program_check" < /dev/null > /dev/null
program_check="python3-pip"
DEBIAN_FRONTEND=noninteractive apt-get install -qq "$program_check" < /dev/null > /dev/null
sudo -u "$install_user" pip -q install --user beets
#Install dependancies for beets plugins
#acousticid
sudo -u "$install_user" pip -q install pyacoustid
#gmusic upload, still needed?
sudo -u "$install_user" pip -q install gmusicapi
#chroma
program_check="libchromaprint-tools"
prog_check_deb
#
#
#+-------------------+
#+---"Script Exit"---+
#+-------------------+
rm -r /tmp/"$lockname"
if [[ $? -ne 0 ]]; then
    eerror "error removing lockdirectory"
    exit 65
else
    enotify "successfully removed lockdirectory"
fi
esilent "$lockname completed"
exit 0

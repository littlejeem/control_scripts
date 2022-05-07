#!/usr/bin/env bash
#
#############################################################################################
### "This is a script designed to automate the ripping of blurays and converting them,    ###
### into my chosen container format.                                                      ###
### The script relies on the supreme work of the developers of:                           ###
### - makemkv: to rip the disc                                                            ###
### - HandBrakeCLI: to encode the ripped disc                                             ###
### - jq: to parse and manipualte .json data                                              ###
### - udftools: Used to extract data from the vlabel from the optical media               ###
### - curl: used to send and receive data from omdbapi                                    ###
### - omdbapi: user omdb key used to lookup information about media title online          ###
### as well as some other stuff:                                                          ###
### - helper_script: from my repository https://github.com/littlejeem/standalone_scripts, ###
### used for debugging and various helper functions.                                      ###
### Place or symlink the files helper_script.sh, config.sh, omdb_key into /usr/local/bin  ###
#############################################################################################
#
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
#+----------------------+
#+---"Check for Root"---+
#+----------------------+
#only needed if root privaleges necessary, enable
#if [[ $EUID -ne 0 ]]; then
#    echo "Please run this script with sudo:"
#    echo "sudo $0 $*"
#    exit 66
#fi
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
#+---------------------+
#+---"Set Variables"---+
#+---------------------+
#set default logging level, failure to set this will cause a 'unary operator expected' error
#remember at level 3 and lower, only esilent messages show, best to include an override in getopts
verbosity=3
#
version="1.3" #
notify_lock="/tmp/$lockname"
#pushover_title="NAME HERE" #Uncomment if using pushover
#
#
#+-------------------------------------+
#+---"Source helper script & others"---+
#+-------------------------------------+
if [[ -f /usr/local/bin/helper_script.sh ]]; then
  source /usr/local/bin/helper_script.sh
  einfo "helper_script located, using"
else
  echo "/usr/local/bin/helper_script.sh, please correct"
fi
if [[ -f /usr/local/bin/config.sh ]]; then
  source /usr/local/bin/config.sh
  einfo "helper_script located, using"
else
  echo "/usr/local/bin/config_script.sh, please correct"
fi
if [[ -f /usr/local/bin/omdb_key ]]; then
  source /usr/local/bin/omdb_key
  einfo "omdb_key file found, using"
else
  echo "/usr/local/bin/omdb_key, please correct"
fi
#
#
#+---------------------------------------+
#+---"check if script already running"---+
#+---------------------------------------+
check_running
#
#
#+---------------------+
#+---"Set functions"---+
#+---------------------+
#SVGHhresct:n:q:
helpFunction () {
   echo ""
   echo "Usage: $0 $scriptlong"
   echo "Usage: $0 $scriptlong -G -r -t ## -n "TITLE HERE" -q ## -s -c"
   echo "Usage: $0 $scriptlong -G -e -t ## -n "TITLE HERE" -q ## -s -c"
   echo -e "\t Running the script with no flags causes default behaviour with logging level set via 'verbosity' variable"
   echo -e "\t-S Override set verbosity to specify silent log level"
   echo -e "\t-V Override set verbosity to specify Verbose log level"
   echo -e "\t-G Override set verbosity to specify Debug log level"
   echo -e "\t-h -H Use this flag for help"
   echo -e "\t-r Rip Only: Will cause the script to only rip the disc, not encode. NOTE: -r & -e cannot both be set"
   echo -e "\t-e Encode Only: Will cause the script to encode to container only, no disc rip. NOTE: -r & -e cannot both be set"
   echo -e "\t-s Source delete override: By default the script removes the source files on completion. Selecting this flag will keep the files"
   echo -e "\t-p Disable the progress bars in the script visible in terminal, useful when debugging rest of script"
   echo -e "\t-c Temp Override: By default the script removes any temp files on completion. Selecting this flag will keep the files, useful if debugging"
   echo -e "\t-t Manually provide the title to rip eg. -t 42"
   echo -e "\t-n Manually provide the feature name to lookup eg. -n "BETTER TITLE", useful for those discs that aren't helpfully named"
      echo -e "\t-q Manually provide the quality to encode in handbrake, eg. -q 21. default value is 19, anything lower than 17 is considered placebo"
   #
   if [ -d "/tmp/$lockname" ]; then
     einfo "removing lock directory"
     rm -r "/tmp/$lockname"
   else
     einfo "problem removing lock directory"
   fi
   exit 65 # Exit script after printing help
}
#
convert_secs_hr_min () {
  #from here https://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds
  num=$(echo $secs)
  min=0
  hour=0
  if((num>59));then
      ((sec=num%60))
      ((num=num/60))
          if((num>59));then
          ((min=num%60))
          ((num=num/60))
              if((num>23));then
                  ((hour=num%24))
              else
                  ((hour=num))
              fi
          else
              ((min=num))
          fi
      else
      ((sec=num))
  fi
  hour=`seq -w 00 $hour | tail -n 1`
  min=`seq -w 00 $min | tail -n 1`
  sec=`seq -w 00 $sec | tail -n 1`
  printf "$hour:$min:$sec"
}
#
clean_main_feature_scan () {
  #we use sed to take all text after (inclusive) "Version: {" from main_feature_scan.json and put it into main_feature_scan_trimmed.json
  #sed -n '/Version: {/,$w main_feature_scan_trimmed.json' main_feature_scan.json
  #we use sed to take all text after (inclusive) "JSON Title Set: {" from main_feature_scan.json and put it into main_feature_scan_trimmed.json
  sed -n '/JSON Title Set: {/,$w main_feature_scan_trimmed.json' main_feature_scan.json
  #now we need to delete the top line left as "JSON Title Set: {"
  sed -i '1d' main_feature_scan_trimmed.json
  #we now  need to insert a spare '{' & a '[' at the start of the file
  sed -i '1s/^/{\n/' main_feature_scan_trimmed.json
  sed -i '1s/^/[\n/' main_feature_scan_trimmed.json
  #and now we need to add ']' to the end of the file
  echo "]" >> main_feature_scan_trimmed.json
  einfo "... main_feature_scan_trimmed.json created"
}
#
source_clean () {
  if [[ -z "$source_clean_override" ]] && [[ -z "$rip_only" ]] && [[ -z "$encode_only" ]]; then
    einfo "removing source files..."
    if [[ -d "$makemkv_out_loc" ]]; then
      rm -r "$makemkv_out_loc" || { einfo "Failure removing source directory"; exit 65; }
      einfo "...source files removed"
    fi
  fi
}
#
temp_clean () {
  if [[ -z "$temp_clean_override" ]]; then
    einfo "removing temp files..."
    if [[ -d "$working_dir/temp/$bluray_name" ]]; then
      cd "$working_dir/temp" || { einfo "Failure changing to temp working directory"; exit 65; }
      rm -r "$bluray_name"
      einfo "...temp files removed"
    fi
  fi
}
#
script_exit () {
  if [ -d /tmp/"$lockname" ]; then
    rm -r /tmp/"$lockname"
    if [[ $? -ne 0 ]]; then
        eerror "error removing lockdirectory"
        exit 65
    else
        enotify "successfully removed lockdirectory"
    fi
  fi
  esilent "$lockname completed"
  exit 0
}
#
clean_ctrlc () {
  let ctrlc_count++
  echo
  if [[ $ctrlc_count == 1 ]]; then
    echo "Quit command detected, are you sure?"
  elif [[ $ctrlc_count == 2 ]]; then
    echo "...once more and the script will exit..."
  else
    echo "...exiting script."
    #
    if [[ ! -z "$makemkv_pid" ]]; then
      einfo "Terminating rip"
      kill $makemkv_pid
      sleep 2
    fi
    #
    if [[ ! -z "$handbrake_pid" ]]; then
      einfo "Terminating encode"
      kill $handbrake_pid
      sleep 2
      [ -d "$output_loc" ] && rm -r "$output_loc" || einfo "no output folder to delete"
    fi
    #
    source_clean
    temp_clean
    script_exit
  fi
}
#
clean_exit () {
 if [[ ! -z "$makemkv_pid" ]]; then
   einfo "Terminating rip"
   kill $makemkv_pid
   sleep 2
 fi
 #
 if [[ ! -z "$handbrake_pid" ]]; then
   einfo "Terminating encode"
   kill $handbrake_pid
   sleep 2
   [ -d "$output_loc" ] && rm -r "$output_loc" || einfo "no output folder to delete"
 fi
 #
 source_clean
 temp_clean
 script_exit
}
#
dirty_exit () {
  source_clean_override=1
  temp_clean_override=1
  if [[ ! -z "$makemkv_pid" ]]; then
    einfo "Terminating rip"
    kill $makemkv_pid
    sleep 2
  fi
  #
  if [[ ! -z "$handbrake_pid" ]]; then
    einfo "Terminating encode"
    kill $handbrake_pid
    sleep 2
    [ -d "$output_loc" ] && rm -r "$output_loc" || einfo "no output folder to delete"
  fi
  if [ -d /tmp/"$lockname" ]; then
    rm -r /tmp/"$lockname"
    if [[ $? -ne 0 ]]; then
        eerror "error removing lockdirectory"
        exit 65
    else
        enotify "successfully removed lockdirectory"
    fi
  fi
  eerror "$lockname experienced an error"
  if [ $handbrake_exit_code -gt 0 ]; then
    error "error found with handbrake"
  fi
  exit 66
}
#
#
#+------------------------+
#+---"Get User Options"---+
#+------------------------+
esilent "$lockname started"
while getopts ":SVGHhrespct:n:q:" opt
do
    case "${opt}" in
        S) verbosity=$silent_lvl
        einfo "-S specified: Silent mode";;
        V) verbosity=$inf_lvl
        einfo "-V specified: Verbose mode";;
        G) verbosity=$dbg_lvl
        einfo "-G specified: Debug mode";;
        r) rip_only=1
        einfo "-r rip_only selected, only ripping not encoding";;
        e) encode_only=1
        einfo "-e encode_only selected, only encoding not ripping";;
        s) source_clean_override=1
        einfo "-s source clean override selected, keeping SOURCE files";;
        p) bar_override=1
        einfo "-p bar_override selected disabling progress bars";;
        c) temp_clean_override=1
        einfo "-c temp clean override selected, keeping TEMP files";;
        t) title_override=${OPTARG}
        einfo "-t title_override chosen, using title number: $title_override instead of automatically found main title";;
        n) name_override=${OPTARG}
        einfo "-n name override given, using supplied title name of: $name_override";;
        q) quality_override=${OPTARG}
        if (( $quality_override >= 17 && $quality_override <= 99 )); then
          quality=$quality_override
          einfo "-q quality_override chosen, using supplied Q value of: $quality_override"
        else
          eerror "quality_override must be between 17-99"
          helpFunction
        fi;;
        H) helpFunction;;
        h) helpFunction;;
        ?) helpFunction;;
    esac
done
# Check both encode only and rip only are not set
if [[ ! -z "$encode_only" && ! -z "$rip_only" ]]; then
  eerror "You can't set both rip only & encode only as that is the scripts standard behaviour with no flags set"
  helpFunction
  exit 64
fi
#
# Check if running in a terminal
tty -s
if [[ $? = 0 ]]; then
  if [[ -z $bar_override ]]; then
    einfo "terminal mode detected, using progress bars" #>> /home/jlivin25/bin/terminal_log_test.log
  else
    einfo "progress bars overridden" #>> /home/jlivin25/bin/terminal_log_test.log
  fi
else
  einfo "not running in terminal mode, disabling progress bars" #>> /home/jlivin25/bin/terminal_log_test.log
  bar_override=1
fi
#
einfo "bar_override is: $bar_override"
#
# check if media in drive and bail if not
blockdev --getsize64 $dev_drive > /dev/null
if [[ $? -gt 0 ]]; then
  eerror "something wrong with optical media, no media in drive??"
  if [ -d "/tmp/$lockname" ]; then
     einfo "removing lock directory"
     rm -r "/tmp/$lockname"
   else
     einfo "problem removing lock directory"
   fi
  exit 66
fi
#
#
#+-------------------+
#+---"Trap ctrl-c"---+
#+-------------------+
trap clean_ctrlc SIGINT
trap clean_exit SIGTERM
ctrlc_count=0
#
#
#+----------------------------------------------+
#+---"Check necessary programs are installed"---+
#+----------------------------------------------+
program_check="HandBrakeCLI"
prog_check
program_check="makemkvcon"
prog_check
program_check="curl"
prog_check
program_check="jq"
prog_check
program_check="udfinfo"
prog_check
#
#
#+----------------------+
#+---"Script Started"---+
#+----------------------+
# At this point the script is set up and all necessary conditions recorded or imported.
esilent "$lockname started"
#
#
#+--------------------------------------+
#+---"Display some info about script"---+
#+--------------------------------------+
einfo "Version of $scriptlong is: $version"
einfo "Version of helper_script is: $helper_version"
einfo "PID is $script_pid"
#
#
#+---------------------+
#+---"Set up script"---+
#+---------------------+
#Get environmental info
einfo "INVOCATION_ID is set as: $INVOCATION_ID"
einfo "EUID is set as: $EUID"
einfo "PATH is: $PATH"
#
#
#+-----------------------------------+
#+---"Check settings from .config"---+
#+-----------------------------------+
einfo "source media drive us $dev_drive"
drive_num=${dev_drive: -1}
einfo "drive_num: $drive_num"
makemkv_drive="disc:$drive_num"
einfo "makemkv drive is: $makemkv_drive"
einfo "working directory is: $working_dir"
einfo "category is: $category"
einfo "destination for Rips is: $rip_dest"
einfo "destination for Encodes is: $encode_dest"
#
#
#+--------------------------------+
#+---"Any additional variables"---+
#+--------------------------------+
banned_list="™ Blu-ray blu-ray Blu-Ray TITLE_1 DISC_1 Blu-ray™"
banned_name_endings="- @ :"
#
#
#+----------------------------+
#+---"Main Script Contents"---+
#+----------------------------+
#Check Enough Space Remaining, will only work once variables moved to config script
space_left=$(df $working_dir | awk '/[0-9]%/{print $(NF-2)}')
einfo "space left in working directory is: $space_left"
if [ "$space_left" -le 65000000 ]; then
  eerror "not enough space to run rip & encode, terminating"
  exit 66
else
  einfo "Free space check passed, continuing"
fi
#
#Configure Disc Ripping
if [[ -z $quality_override ]]; then
  quality="19.0"
fi
einfo "quality selected is $quality"
#
#Get and use hard coded name of media
bluray_name=$(blkid -o value -s LABEL "$dev_drive")
bluray_name=${bluray_name// /_}
einfo "optical disc bluray name is: $bluray_name"
#
#
#Perhpas build up a list of known FOOBAR'd disc labels such as 'LOGICAL_VOLUME, DISC1 etc?'
#Get name of media according to syslogs, this will only work if this script is being used automatically via UDEV / SYSTEMD otherwise name likely to me buried in older logs
#bluray_sys_name=$(grep "UDF-fs: INFO Mounting volume" /var/log/syslog | tail -1 | cut -d ':' -f 5 | cut -d ' ' -f 5)
bluray_sys_name=$(udfinfo "$dev_drive" 2> /dev/null | grep 'vid' | tail -1 | cut -d '=' -f 2)
#set what to do if result is found
#perhaps make it more fancy so if bluray_name doesn't contain bluray_sys_name use bluray_sys_name?
if [[ ! -z $bluray_sys_name ]]; then
  einfo "bluray_sys_name found, using: $bluray_sys_name"
  bluray_name=$bluray_sys_name
fi
# create the temp dir, failure to set this will error out handrake parsing info
mkdir -p "$working_dir/temp/$bluray_name"
#
#
#+-------------------------+
#+---"Setup Ripping"---+
#+-------------------------+
#set output location for makemkv, not in "encode_only as is used in handrake as $source_loc"
if [[ ! -z "$working_dir" ]] && [[ ! -z "$rip_dest" ]] && [[ ! -z "$category" ]] && [[ ! -z "$bluray_name" ]]; then
  einfo "valid Rips (source) directory, creating"
  makemkv_out_loc="$working_dir/$rip_dest/$category/$bluray_name"
  mkdir -p "$makemkv_out_loc"
else
  eerror "error with necessary variables to create Rips(source files) location"
  exit 65
fi
einfo "Rip / Source files will be at: $makemkv_out_loc"
#
#
#+-------------------------+
#+---"Carry Out Ripping"---+
#+-------------------------+
if [[ -z "$encode_only" ]]; then
  #Set up functions to get information for progress bar
  get_max_progress () {
    tail -n 1 "$working_dir/temp/$bluray_name/$bluray_name.log" | cut -d ',' -f 3
  }
  #
  get_total_progress () {
    tail -n 1 "$working_dir/temp/$bluray_name/$bluray_name.log" | cut -d ',' -f 2
  }
  #
  einfo "final values passed to makemkvcon are: backup --decrypt --progress=$working_dir/temp/$bluray_name/$bluray_name.log -r $makemkv_drive $makemkv_out_loc"
  esilent "Ripping started..."
  unit_of_measure="cycles"
  makemkvcon backup --decrypt --progress="$working_dir/temp/$bluray_name/$bluray_name.log" -r "$makemkv_drive" "$makemkv_out_loc" > /dev/null 2>&1 &
  makemkv_pid=$!
  pid_name=$makemkv_pid
  sleep 15s # to give time for drive to wind up and files to be created
  if [[ -z $bar_override ]]; then
    progress_bar2_init
    if [ $? -eq 0 ]; then
      einfo "...ripping complete"
    else
      eerror "makemkv produced an error, code: $?"
      exit 66
    fi
  else
    einfo "progress bars overridden"
    wait $makemkv_pid
    einfo "...ripping complete"
  fi
fi
#
#
#+----------------------+
#+---"Setup Encoding"---+
#+----------------------+
#
options="--json --no-dvdna"
source_loc="$makemkv_out_loc" #this should match the makemkv output location
output_options="-f mkv"
container_type="mkv"
video_options="-e x264 --encoder-preset medium --encoder-tune film --encoder-profile high --encoder-level 4.1 -q $quality -2"
picture_options="--crop 0:0:0:0 --loose-anamorphic --keep-display-aspect --modulus 2"
filter_options="--decomb"
subtitle_options="-N eng -F scan"
#
#make the working directory if not already existing
#this step is vital, otherwise the files below are created whereever the script is run from and will fail
cd "$working_dir/temp/$bluray_name" || { einfo "Failure changing to working directory temp"; exit 65; }
#
#Grab all titles from source
einfo "scanning source location for titles..."
HandBrakeCLI --json -i $source_loc -t 0 --main-feature &> all_titles_scan.json
handbrake_exit_code=$?
edebug "HB exit code was: $handbrake_exit_code"
#we ignore 3 because the scan always produces this error it its not a fail for purposes of this script
if [ $handbrake_exit_code -eq 0 ]; then
  einfo "...location scan completed."
elif [ $handbrake_exit_code -eq 1 ]; then
  eerror "...handbrake scan process was cancelled"
  dirty_exit
elif [ $handbrake_exit_code -eq 2 ]; then
  eerror "...handbrake scan, invalid input. Invalid input name, no size?"
  dirty_exit
elif [ $handbrake_exit_code -eq 4 ]; then
  eerror "...handbrake produced an unknown error"
  dirty_exit
fi
#search file for identified main feature
auto_found_main_feature=$(grep -w "Found main feature title" all_titles_scan.json)
if [[ -z $auto_found_main_feature ]]; then
  eerror "Something went wrong with auto_found_main_feature"
  exit 66
fi
einfo "auto_found_main_feature is: $auto_found_main_feature"
#we cut unwanted "Found main feature title " text from the variable
auto_found_main_feature=${auto_found_main_feature:25}
einfo "auto_found_main_feature cut to: $auto_found_main_feature"
#
#NOW CREATE main feature_scan
einfo "creating main_feature_scan.json ..."
#do X if no title over-ride, else use the title over-ride
if [[ -z $title_override ]]; then
  HandBrakeCLI --json -i $source_loc -t $auto_found_main_feature --scan 1> main_feature_scan.json 2> /dev/null
else
  HandBrakeCLI --json -i $source_loc -t $title_override --scan 1> main_feature_scan.json 2> /dev/null
fi
#
#CLEAN FILE FOR JQ
clean_main_feature_scan
#SEARCH FOR FEATURE NAME VIA JQ, unless override in place
if [[ -z $name_override ]]; then
  feature_name=$(jq --raw-output '.[].TitleList[].Name' main_feature_scan_trimmed.json | head -n 1 | sed -e "s/ /_/g")
else
  feature_name="$name_override"
fi
einfo "feature name is: $feature_name"
#
#CLEAN THE FOUND LOCAL TITLE TO SEARCH WITH
#extract '_' in name
field_count="${feature_name//[^_]}"
edebug "delimeter pick is: $field_count"
#count them
field_count="${#field_count}"
edebug "count of delimiters is: $field_count, so $((field_count+1)) elements"
#increase delimeter count by 1 so it represents number of fields/elements
field_count=$((field_count+1))
edebug "field_count +1 is: $field_count"
#
#start the array
title_array=() # declare an empty array; same as: declare -a groups
#for i in {1..5..1}; do
for ((i=1;i<=field_count;i++)); do
  title_array[i]=$(echo $feature_name | cut -d '_' -f $i)
  edebug "element is: $i, value is: ${title_array[i]}"
  if [[ $banned_list =~ (^|[[:space:]])${title_array[i]}($|[[:space:]]) ]]; then
    edebug "element matches banned list removing from array"
    unset title_array[i]
  else
    edebug "valid title content, using"
  fi
done
#
# Print the resulting array's elements.
#printf '%s\n' "${title_array[@]}"
edebug "array element 1: ${title_array[1]}"
# check if element 1 is a number and if so greater than year format for movie titles, eg 1949 would be valid but 83442423 (in disc lable) woudl not be
if [[ ${title_array[1]} =~ ^[0-9]+$ ]] && [[ ${title_array[1]} -ge 9999 ]]; then
  edebug "element1 of array equaled a number of 10000 or more, unlikely to part of a valid film title removing from array"
  #remove from array if it is bigger than should be
  unset title_array[1]
  edebug "element array now shows:"
  # printf '%s\n' "${groups[@]}"
  feature_name=( "${title_array[*]}" )
  edebug "online feature name check now set for: $feature_name"
else
  edebug "Array element 1 not a number so using"
fi
#
if [[ $banned_name_endings =~ (^|[[:space:]])${title_array[-1]}($|[[:space:]]) ]]; then
  edebug "last of array matches the banned ending element list, removing from array"
  unset title_array[-1]
  feature_name=( "${title_array[*]}" )
  edebug "online feature name check now set for: $feature_name"
else
  edebug "last element in array passes checks, using"
fi
#
feature_name=$(echo "${title_array[*]}")
feature_name_prep="${feature_name//_/ }"
edebug "$feature_name_prep"
# do some work to make the array result acceptable for a http api request, replace ' ' with '+'
feature_name_prep="${feature_name_prep// /+}"
edebug "$feature_name_prep"
#create http segment in a variable so that individual variables don't need expanding in curl request, it doesn't work!
http_construct="http://www.omdbapi.com/?t=$feature_name_prep&apikey=$omdb_apikey"
#
#run online query
einfo "http_construct is: $http_construct"
einfo "Querying omdb..."
#omdb_title_result=$(curl -sX GET --header "Accept: */*" "http://www.omdbapi.com/?t=${feature_name}&apikey=${omdb_apikey}")
omdb_title_result=$(curl -sX GET --header "Accept: */*" "$http_construct")
#
#IF ONLINE SEARCH SUCCEEDS DO EXTRA.
#{"Response":"False","Error":"Incorrect IMDb ID."}
if [[ "$omdb_title_result" = *'"Title":"'* ]]; then
  edebug "omdb matching info is: $omdb_title_result"
  omdb_title_name_result=$(echo $omdb_title_result | jq --raw-output '.Title')
  einfo "omdb title name is: $omdb_title_name_result"
  omdb_year_result=$(echo $omdb_title_result | jq --raw-output '.Year')
  einfo "omdb year is: $omdb_year_result"
  einfo "Getting runtime info..."
  #extract runtime from mass omdb result
  omdb_runtime_result=$(echo $omdb_title_result | jq --raw-output '.Runtime')
  #strip out 'min'
  omdb_runtime_result=${omdb_runtime_result%????}
  einfo "omdb runtime is (mins): $omdb_runtime_result ..."
  einfo "...converting to hh:mm:ss"
  omdb_runtime_result=$((omdb_runtime_result*60))
  secs=$omdb_runtime_result
  omdb_runtime_result=$(convert_secs_hr_min)
  einfo "omdb runtime in hh:mm:ss format is: $omdb_runtime_result"
  #
  #START ARRAY WORK TO ANALYSE TRACK TIMES AND ROUND UP SO AS TO COMPART TO OMDB TIMES
  track_times_array=()
  array_matching_track=()
  #find all results matching MPLS in all_titles_scan.json and save the time from the line afterwards...
  #...remove all blank lines and those with -- in them and save result list to grepped_times file
  grep -A 1 MPLS all_titles_scan.json | cut -d ' ' -f 5 | cut -d ' ' -f 1 | awk 'NF' | sed '/--/d' > grepped_times
  #remove last line of file (auto_found_main_features time)
  sed -i '$d' grepped_times
  #remove last line of file (auto_found_main_features title)
  sed -i '$d' grepped_times
  #read in grepped file to array
  mapfile -t track_times_array <grepped_times
  #time conversion work in array
  for ((i=0; i<${#track_times_array[@]}; i++)); do
    #TRACK DETAILS
    track_num=$((i+1))
    edebug "--------------------------------------------"
    edebug "Running time of track $track_num is: ${track_times_array[$i]}"
    #
    #SECONDS
    track_secs_old=$(echo ${track_times_array[$i]} | cut -d ':' -f 3)
    #remove padding zeros to reduce 'base 8 errors'
    #track_secs_new=${track_secs_old##+(0)}
    track_secs_new=${track_secs_old#0}
    if [[ $track_secs_new -ge 31 ]]; then
      edebug "rounding up seconds"
      track_secs_new=0
      inc_mins=1
    else
      track_secs_new=0
      inc_mins=
    fi
    track_secs_new=$(printf "%02d\n" $track_secs_new)
    edebug "seconds = $track_secs_new"
    #
    #MINS
    track_mins_old=$(echo ${track_times_array[$i]} | cut -d ':' -f 2)
    #remove padding zeros to reduce 'base 8 errors'
    track_mins_new=${track_mins_old#0}
    edebug "track_mins being used are: $track_mins_new"
    if [[ ! -z $inc_mins ]]; then
      edebug "track_mins_new before rounding = $track_mins_new"
      track_mins_new=$((track_mins_new+1))
      edebug "track_mins after rounding = $track_mins_new"
    fi
    if [[ $track_mins_new -ge 59 ]]; then
      edebug "rounding up minutes"
      track_mins_new=0
      inc_hours=1
    else
      inc_hours=
    fi
    track_mins_new=$(printf "%02d\n" $track_mins_new)
    edebug "mins = $track_mins_new"
    #
    #HOURS
    track_hours_old=$(echo ${track_times_array[$i]} | cut -d ':' -f 1)
    #remove padding zeros to reduce 'base 8 errors'
    #track_hours_new=${track_hours_old##+(0)}
    track_hours_new=${track_hours_old#0}
    if [[ ! -z $inc_hours_new ]]; then
      edebug "track_hours before rounding = $track_hours_new"
      track_hours_new=$((track_hours_new+1))
      edebug "track_hours_new after rounding = $track_hours_new"
    fi
    if [[ $track_hours_new -ge 59 ]]; then
      edebug "really, 60 hour film?!!!"
      track_hours=0
    fi
    track_hours_new=$(printf "%02d\n" $track_hours_new)
    edebug "hours = $track_hours_new"
    #
    # COMPARISON WORK
    local_track_time=$(echo "$track_hours_new:$track_mins_new:$track_secs_new")
    edebug "new track time is: $local_track_time"
    edebug "omdb_runtime is: $omdb_runtime_result"
    if [[ "$local_track_time" = "$omdb_runtime_result" ]]; then
      edebug "track matched, using"
      array_matching_track+=( $track_num )
    else
      edebug "no match"
    fi
    done
    edebug "array_matching_track contents are: ${array_matching_track[@]}"
    edebug "element 0 = ${array_matching_track[0]}"
    edebug "element 1 = ${array_matching_track[1]}"
    if [[ ${#array_matching_track[@]} -gt 0 ]]; then
      if [[ ${#array_matching_track[@]} -gt 1 ]]; then
        matching_track_text="Matching runtime tracks detected as:"
        matching_track_list=${array_matching_track[@]}
        edebug "$matching_track_text $matching_track_list"
        for ((i=0, j=1; i<${#array_matching_track[@]}; i++, j++)); do
        	edebug "j is: $j"
        	edebug "i is: $i"
        	edebug "array_matching_track is: ${array_matching_track[$i]}"
          export "title_$j"="${array_matching_track[$i]}"
        	edebug "inside loop title_$j is set as: ${array_matching_track[$i]}"
        done
      else
        matching_track_text="Matching runtime track detected as:"
        matching_track_list=${array_matching_track[@]}
        edebug "$matching_track_text $dts_track_list"
        for ((i=0, j=1; i<${#array_matching_track[@]}; i++, j++)); do
          edebug "j is: $j"
        	edebug "i is: $i"
        	edebug "array_matching_track is: ${array_matching_track[$i]}"
          export "title_$j"="${array_matching_track[$i]}"
        	edebug "inside loop title_$j is set as: ${array_matching_track[$i]}"
        done
      fi
    else
      einfo "No title track matching runtime found"
      matching_track_list=
    fi
    #
  #
elif [[ "$omdb_title_result" = *'"Error":"No API key provided."'* ]]; then
  einfo "online search failed not doing extra stuff"
  omdb_title_result=
elif [[ "$omdb_title_result" = *'"Error":"Incorrect IMDb ID."'* ]]; then
  einfo "omdb search ran but no matching result could be found"
  omdb_title_result=
elif [[ "$omdb_title_result" = *'"Error":"Movie not found!"'* ]]; then
  einfo "omdb search ran but no matching result could be found"
  omdb_title_result=
elif [[ "$omdb_title_result" = *'</html>nter>cloudflare</center>></center>d>'* ]]; then
  einfo "omdb search ran but no matching result could be found"
  omdb_title_result=
else
  einfo "Some other error occured, dumping omdb_title_result"
  einfo "omdb_title_result is: $omdb_title_result"
  omdb_title_result=
fi
#
#TEST RESULTS TO SEE WHICH TO CHOOSE AND IF DIFFERENT TO OUT AUTO FIND TITLE WE NEED TO RECREATE main_feature_scan.json BEFORE AUDIO CHECK
if [[ -z "$title_1" ]] && [[ -z "$title_2" ]]; then
  einfo "no online data to use, so using local data"
elif [[ ! -z "$title_1" ]] && [[ ! -z "$title_2" ]]; then
  enotify "online check resulted in both titles (title_1: $title_1 & title_2: $title_2) matching the runtime of handbrakes automatically found main feature: $auto_found_main_feature. Using title_2"
  #we choose title 2 when there are 2 detected as this better than 50% right most of the time imo.
  mv main_feature_scan.json main_feature_scan.json.original
  auto_found_main_feature=$(echo $title_2)
  HandBrakeCLI --json -i $source_loc -t $auto_found_main_feature --scan 1> main_feature_scan.json 2> /dev/null
  clean_main_feature_scan
elif [[ -z "$title_1" ]] && [[ ! -z "$title_2" ]]; then #title 1 doesnt match but title 2 does, use it.
  einfo "online check resulted in title_2, matching handbrakes automatically found main feature $auto_found_main_feature, using title_2"
  mv main_feature_scan.json main_feature_scan.json.original
  auto_found_main_feature=$(echo $title_2)
  HandBrakeCLI --json -i $source_loc -t $auto_found_main_feature --scan 1> main_feature_scan.json 2> /dev/null
  clean_main_feature_scan
elif [[ ! -z "$title_1" ]] && [[ -z "$title_2" ]]; then
  #then title 1 is set but if $title_2 is valid $title_2 is set
  einfo "online check resulted in only title_1: $title_1 matching handbrakes automatically found main feature, so using"
fi
#
#EXTRACT AUDIO TRACKS FROM $main_feature_scan_trimmed into parsed_audio_tracks
jq '.[].TitleList[].AudioList[].Description' main_feature_scan_trimmed.json > parsed_audio_tracks
#
#+----------------------------------+
#+---"Determine Availiable Audio"---+
#+----------------------------------+
#First we search the file for the line number of our preferred source because line number = track number of the audio
#these tests produce boolean returns
#
#set up arrays we will use
bdlpcm_array=()
truehd_array=()
dtshd_array=()
dts_array=()
ac3_51_array=()
ac3_array=()
#read file into the array
mapfile -t parsed_audio_array <parsed_audio_tracks
#show ray array contents once read in from file
edebug "array contents are: ${parsed_audio_array[@]}"
#for each array entry search for specific set text, if found add that entry to relevant array defined above
for ((i=0; i<${#parsed_audio_array[@]}; i++)); do
  #"(BD LPCM)"
  if [[ ${parsed_audio_array[$i]} =~ (^|[[:space:]])"(BD LPCM)"($|[[:space:]]) ]]; then
    bdlpcm_track[i]=$((i+1))
    edebug "Bluray uncompressed LPCM detected at element $i, audio track: ${bdlpcm_track[i]}"
    bdlpcm_array+=( ${bdlpcm_track[i]} )
  fi
  #"(TrueHD)"
  if [[ ${parsed_audio_array[$i]} =~ (^|[[:space:]])"(TrueHD)"($|[[:space:]]) ]]; then
    truehd_track[i]=$((i+1))
    edebug "TrueHD detected at element $i, audio track: ${truehd_track[i]}"
    truehd_array+=( ${truehd_track[i]} )
  fi
  #"(DTS-HD MA)"
  if [[ ${parsed_audio_array[$i]} =~ (^|[[:space:]])"(DTS-HD"[[:space:]]"MA)"($|[[:space:]]) ]]; then
    dtshd_track[i]=$((i+1))
    edebug "DTS-HD detected at element $i, audio track: ${dtshd_track[i]}"
    dtshd_array+=( ${dtshd_track[i]} )
  fi
  #"(DTS)"
  if [[ ${parsed_audio_array[$i]} =~ (^|[[:space:]])"(DTS)"($|[[:space:]]) ]]; then
    dts_track[i]=$((i+1))
    edebug "DTS detected at element $i, audio track: ${dts_track[i]}"
    dts_array+=( ${dts_track[i]} )
  fi
  #"(AC3) (5.1"
  if [[ ${parsed_audio_array[$i]} =~ (^|[[:space:]])"(AC3)"[[:space:]]"(5.1"($|[[:space:]]) ]]; then
    ac3_51_track[i]=$((i+1))
    edebug "AC3 5.1 detected at element $i, audio track: ${ac3_51_track[i]}"
    ac3_51_array+=( ${ac3_51_track[i]} )
  fi
  if [[ ${parsed_audio_array[$i]} =~ (^|[[:space:]])"(AC3)"[[:space:]]"(2.0"($|[[:space:]]) ]]; then
    ac3_track[i]=$((i+1))
    edebug "AC3 2.0 detected at element $i, audio track: ${ac3_track[i]}"
    ac3_array+=( ${ac3_track[i]} )
  fi
done
#
#construct messaging text and set *audio_track_list. If more than one entry seperate them by ', '
#so they will be format required by handbrake for multiple tracks, set variable single value or to empty if no tracks found.
#"*BD LPCM*"
if [[ ${#bdlpcm_array[@]} -gt 0 ]]; then
  if [[ ${#bdlpcm_array[@]} -gt 1 ]]; then
    bdlpcm_text="tracks:"
    bdlpcm_track_list=${bdlpcm_array[@]}
    bdlpcm_track_list=${bdlpcm_track_list// /,}
    einfo "BD LPCM detected on $bdlpcm_text $bdlpcm_track_list"
  else
    bdlpcm_text="BD LPCM detected on track:"
    bdlpcm_track_list=${bdlpcm_array[@]}
    einfo "BD LPCM detected on $bdlpcm_text $bdlpcm_track_list"
  fi
else
  einfo "NO BD LPCM tracks detected"
  bdlpcm_track_list=
fi
#
#"*TrueHD*"
if [[ ${#truehd_array[@]} -gt 0 ]]; then
  if [[ ${#truehd_array[@]} -gt 1 ]]; then
    truehd_text="tracks:"
    truehd_track_list=${truehd_array[@]}
    truehd_track_list=${truehd_track_list// /,}
    einfo "TrueHD detected on $truehd_text $truehd_track_list"
  else
    truehd_text="track:"
    truehd_track_list=${truehd_array[@]}
    einfo "TrueHD detected on $truehd_text $truehd_track_list"
  fi
else
  einfo "NO TrueHD tracks detected"
  dts_track_list=
fi
#
#"*DTS-HD*"
if [[ ${#dtshd_array[@]} -gt 0 ]]; then
  if [[ ${#dtshd_array[@]} -gt 1 ]]; then
    dtshd_text="tracks:"
    dtshd_track_list=${dtshd_array[@]}
    dtshd_track_list=${dtshd_track_list// /,}
    einfo "DTS-HD detected on $dtshd_text $dtshd_track_list"
  else
    dtshd_text="track:"
    dtshd_track_list=${dtshd_array[@]}
    einfo "DTS-HD detected on $dtshd_text $dtshd_track_list"
  fi
else
  einfo "NO DTS-HD tracks detected"
  dtshd_track_list=
fi
#
#"*DTS*"
if [[ ${#dts_array[@]} -gt 0 ]]; then
  if [[ ${#dts_array[@]} -gt 1 ]]; then
    dts_text="tracks:"
    dts_track_list=${dts_array[@]}
    dts_track_list=${dts_track_list// /,}
    einfo "DTS detected on $dts_text $dts_track_list"
  else
    dts_text="track:"
    dts_track_list=${dts_array[@]}
    einfo "DTS detected on $dts_text $dts_track_list"
  fi
else
  einfo "NO DTS tracks detected"
  dts_track_list=
fi
#
#"*AC3 5.1*"
if [[ ${#ac3_51_array[@]} -gt 0 ]]; then
  if [[ ${#ac3_51_array[@]} -gt 1 ]]; then
    ac3_51_text="tracks:"
    ac3_51_track_list=${ac3_51_array[@]}
    ac3_51_track_list=${ac3_51_track_list// /,}
    einfo "AC3 5.1 detected on $ac3_51_text $ac3_51_track_list"
  else
    ac3_51_text="track:"
    ac3_51_track_list=${ac3_51_array[@]}
    einfo "AC3 5.1 detected on $ac3_51_text $ac3_51_track_list"
  fi
else
  einfo "NO AC3 5.1 tracks detected"
  ac3_51_track_list=
fi
#
#"*AC3 2.0*"
if [[ ${#ac3_array[@]} -gt 0 ]]; then
  if [[ ${#ac3_array[@]} -gt 1 ]]; then
    ac3_text="tracks:"
    ac3_track_list=${ac3_array[@]}
    ac3_track_list=${ac3_track_list// /,}
    einfo "AC3 detected on $ac3_text $ac3_track_list"
  else
    ac3_text="track:"
    ac3_track_list=${ac3_array[@]}
    einfo "AC3 detected on $ac3_text $ac3_track_list"
  fi
else
  ewarn "NO AC3 tracks detected, error??"
  ac3_track_list=
fi
#
#+------------------------------+
#+---"Determine 'Best' Audio"---+
#+------------------------------+
#Now we make some decisons about audio choices
# if its present always prefer, TrueHD; if not, DTS-HD, if not, BD LPCM; if not, DTS; if not, AC3 5.1, and if none of these AC3 2.0 track"
if [[ ! -z "$truehd_track_list" ]]; then #true = TrueHD
  selected_audio_track=$truehd_track_list
  einfo "Selecting True_HD audio on $truehd_text $truehd_track_list"
  audio_codec="TrueHD"
elif [[ ! -z "$truehd_track_list" ]] && [[ ! -z "$dtshd_track_list" ]]; then #true false = TrueHD
  selected_audio_track=$truehd_track_list
  einfo "Selecting True_HD audio on $truehd_text $truehd_track_list"
  audio_codec="TrueHD"
elif [[ -z "$truehd_track_list" ]] && [[ ! -z "$dtshd_track_list" ]]; then #false true = DTS-HD
  selected_audio_track=$dtshd_track_list
  einfo "Selecting DTS-HD audio on $dtshd_text $dtshd_track_list"
  audio_codec="DTS-HD"
elif [[ ! -z "$bdlpcm_track_list" ]] && [[ -z "$truehd_track_list" ]] && [[ -z "$dtshd_track_list" ]]; then #true false false = BD LPCM
  selected_audio_track=$bdlpcm_track_list
  einfo "Selecting BD LPCM audio on $bdlpcm_text $bdlpcm_track_list"
  audio_codec="FLAC"
elif [[ -z "$truehd_track_list" ]] && [[ -z "$dtshd_track_list" ]] && [[ -z "$bdlpcm_track_list" ]] && [[ ! -z "$dts_track_list" ]]; then #false false false true = DTS
  selected_audio_track=$dts_track_list
  einfo "Selecting DTS audio on $dts_text $dts_track_list"
  audio_codec="DTS"
elif [[ -z "$truehd_track_list" ]] && [[ -z "$dtshd_track_list" ]] && [[ -z "$bdlpcm_track_list" ]] && [[ -z "$dts_track_list" ]] && [[ ! -z "$ac3_51_track_list" ]]; then #false, false, flase, false = AC3 5.1
  selected_audio_track=$ac3_51_track_list
  einfo "Selecting AC3 5.1 audio on $ac3_51_text $ac3_51_track_list"
  audio_codec="AC-3"
elif [[ -z "$truehd_track_list" ]] && [[ -z "$dtshd_track_list" ]] && [[ -z "$bdlpcm_track_list" ]] && [[ -z "$dts_track_list" ]] && [[ -z "$ac3_51_track_list" ]]; then #false false false false false false = AC3 (default)
  selected_audio_track=${ac3_array[0]}
  einfo "no matches for preferred audio types, defaulting to first AC3 track: ${ac3_array[0]}"
  audio_codec="AC-3"
fi
#
#insert the audio selection into the audio_options variable, something different wiht BD_lpcm if selected as cannot be passed thru
if [[ $audio_codec == "FLAC" ]]; then
  audio_options="-a $selected_audio_track -E flac24 --mixdown 5point1"
else
  audio_options="-a $selected_audio_track -E copy --audio-copy-mask dtshd,truehd,dts"
fi
einfo "audio options passed to HandBrakeCLI are: $audio_options"
#
#
#+----------------------------+
#+---"Create Encoding Name"---+
#+----------------------------+
#use our found main feature from the work at the top...
source_options="-t $auto_found_main_feature"
#...but override it if override is set
if [[ ! -z "$title_override" ]]; then
  source_options=-"t $title_override"
  einfo "title override selected, using: $title_override"
fi
#display what the result is
einfo "source options are: $source_options"
#
#lets use our fancy name IF found online, else revert to basic
if [[ ! -z "$working_dir" ]] && [[ ! -z "$encode_dest" ]] && [[ ! -z "$category" ]] && [[ ! -z "$omdb_title_name_result" ]] && [[ ! -z "$omdb_year_result" ]] && [[ ! -z "$container_type" ]]; then
  einfo "using online found movie title & year for naming"
  output_loc="$working_dir/$encode_dest/$category/$omdb_title_name_result ($omdb_year_result)/"
  feature_name="${omdb_title_name_result} (${omdb_year_result}) - Bluray-1080p_Proper - $audio_codec.${container_type}"
elif [[ ! -z "$working_dir" ]] && [[ ! -z "$encode_dest" ]] && [[ ! -z "$category" ]] && [[ -z "$omdb_title_result" ]] && [[ ! -z "$feature_name" ]] && [[ ! -z "$container_type" ]]; then
  einfo "using local data based naming"
  output_loc="$working_dir/$encode_dest/$category/$feature_name/"
  feature_name="${feature_name} - Bluray-1080p_Proper - $audio_codec.${container_type}"
else
  eerror "Error setting output_loc, investigation needed"
  exit 64
fi
#echo "$working_dir" "$encode_dest" "$category" "$omdb_title_result" "$omdb_year_result" "$container_type"
#echo "$working_dir" "$encode_dest" "$category" "$omdb_title_result" "$feature_name" "$container_type"
# create the
einfo "output_loc is: $output_loc"
einfo "...creating output_loc if not in existance"
mkdir -p "$output_loc"
einfo "feature name is: $feature_name"
einfo "final file name construct will be: ${output_loc}${feature_name}"
#display the final full options passed to handbrake
einfo "Final HandBrakeCLI Options are: $options -i $source_loc $source_options -o ${output_loc}${feature_name} $output_options $video_options $audio_options $picture_options $filter_options $subtitle_options > $working_dir/temp/$bluray_name/handbrake.log"
#
#
#+--------------------------+
#+---"Carry Out Encoding"---+
#+--------------------------+
# Set out how to get information for progress bar, see notes in helper_script.sh
#
if [[ -z $rip_only ]]; then
  get_max_progress () {
    echo 100
  }
  #
  get_total_progress () {
    #We use this variable in this instance as we need to manipulate the output so interger and no leading zero. eg. '1' no '01'
    #tot_progress_result=$(grep '"Progress":' "$working_dir/temp/$bluray_name"/handbrake.log | tail -1 | cut -d '.' -f 2 | cut -d ',' -f 1 | cut -c-2)
    tot_progress_result=$(grep -a "Progress: {" -A 8 handbrake.log | grep '"WORKING"' -A 7 | grep '"Progress"' | tail -1 | cut -d '.' -f 2 | cut -d ',' -f 1 | cut -c-2)
    tot_progress_result=$((10#$tot_progress_result))
    echo $tot_progress_result
  }
  sleep 1
  esilent "Encoding started..."
  #HandBrakeCLI $options -i $source_loc $source_options -o $output_loc $output_options $video_options $audio_options $picture_options $filter_options $subtitle_options > /dev/null 2>&1 &
  unit_of_measure="percent"
  HandBrakeCLI $options -i $source_loc $source_options -o "${output_loc}${feature_name}" $output_options $video_options $audio_options $picture_options $filter_options $subtitle_options > "$working_dir"/temp/"$bluray_name"/handbrake.log 2>&1 &
  handbrake_pid=$!
  einfo "handbrake_pid: $handbrake_pid"
  pid_name=$handbrake_pid
  einfo "pid name: $pid_name"
  sleep 10s # to give time file to be created and data populating
  if [[ -z $bar_override ]]; then
    progress_bar2_init
    #check for any non zero errors
    if [ $? -eq 0 ]; then
      einfo "...handbrake conversion of: $bluray_name complete."
    else
      eerror "...handbrake produced an error, code: $?"
      exit 66
    fi
  else
    einfo "progress bars overriden"
    wait $handbrake_pid
    einfo "...handbrake conversion of: $bluray_name complete."
  fi
fi
#
#+------------------------------------+
#+---"Clean Up Temp Files & Source"---+
#+------------------------------------+
# clean temp files...if thats not overriden
temp_clean
#
#clean source files...if thats not overriden
source_clean
#
#
#+-------------------+
#+---"Script Exit"---+
#+-------------------+
script_exit

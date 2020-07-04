#!/bin/bash
#
#+---------------------+
#+---"Set Variables"---+
#+---------------------+
stamp=$(echo "`date +%d%m%Y`-`date +%H_%M_%S`")
config_file=/home/jlivin25/bin/myscripts/control_scripts/ripping_scripts/settings.conf
#
#
#+---------------+
#+---Functions---+
#+---------------+
function pushover () {
  if [ "$global_enable_pushover" = 1 ]; then
          echo "sending message via pushover"
  fi
}
#
#
#+-------------------+
#+---"Check Tests"---+
#+-------------------+
if [[ -f $config_file ]]; then
        . $config_file
else
  echo "no settings file found, aborting"
  exit 1;
fi
#
if [ "$enable_bluray" != 1 ]; then
	exit 1;
fi
#
#
#+-----------------------+
#+---""
cd $bluray_output_dir
#
# COMPILE LIST OF ALL RIPPED BLURAYS
bluray_dir_list=( $(find . -maxdepth 1 -type d -printf '%P\n') )

for bluray_title in "${bluray_dir_list[@]}"; do
	if [ "$bluray_title" != 'logs' ] && [ ! -f $bluray_output_dir/$bluray_title.$bluray_extension ]; then
                # LOG : COMMENCING ENCODE OF THIS BLURAY
                echo "*********************************  COMMENCING:  $bluray_title  *********************************" >> $global_log_dir/bluray-encode.log

	        # CHECK FOR THE HandBrakeCLI PROCESS AND GET THE PID
	        handbrake_pid=`ps aux|grep H\[a\]ndBrakeCLI`
	        set -- $handbrake_pid
	        handbrake_pid=$2

	        # WAIT UNTIL PREVIOUS HANDBRAKE PROCESS IS FINISHED
	        if [ -n "$handbrake_pid" ]
	        then
	                while [ -e /proc/$handbrake_pid ]; do sleep 1; done
	        fi
#
#"Move into stream directory and grab name of largest file"
bluray_stream="$bluray_title"/BDMV/STREAM
cd $bluray_stream
largest_title=$(ls -S | head -1)
echo "ripping $largest_title" >> $global_log_dir/bluray-encode.log
pushover
#
		# COMMENCE THE ENCODING
	        #HandBrakeCLI -i $bluray_output_dir/$bluray_title -o $bluray_output_dir/$bluray_title.$bluray_extension $bluray_hb_video $bluray_hb_audio >> $global_log_dir/bluray-encode.log
          HandBrakeCLI --stop-at seconds:1200 --preset-import-file /home/jlivin25/bin/myscripts/control_scripts/ripping_scripts/custom_preset.json -Z "custom-test" -i $bluray_output_dir/$bluray_stream/$largest_title -o $bluray_output_dir/$bluray_title.$bluray_extension
                # LOG : COMPLETED ENCODE
                echo "$(stamp) - COMPLETED:  Completed encode of $bluray_title" >> $global_log_dir/bluray-encode.log

		# CHECK IF FILEN HAS BEEN ENCODED SUCCESSFULLY
                if [ -f "$bluray_output_dir/$bluray_title.$bluray_extension" ]; then
			# GET FILESIZE OF ENCODED FILE
                        bluray_actualsize=$(stat -c%s "$bluray_output_dir/$bluray_title.$bluray_extension")
			# COMPARE ENCODED FILESIZE TO MINIMUM (RESONABLY EXPECTED) FILESIZE - HELPS SPOT ERRORS
                        if [[ "$bluray_actualsize" -gt "$bluray_minimumsize" ]]; then
				# REMOVE RIPPED BLURAY FOLDER (RECOVER 30+GB)
                                if [ "$bluray_enable_cleanup" = 1 ]; then
					rm -R $bluray_output_dir/$bluray_title;
				fi
		                # LOG : REMOVED RIPPED BLURAY
                                echo "$(stamp) -  REMOVED:  Removed backup of $bluray_title" >> $global_log_dir/bluray-encode.log
				# CHECK FOR COUCHPOTATO BLACKHOLE
				if [ "$bluray_enable_blackhole" = 1 ]; then
					# MOVE RIPPED BLURAY TO BLACKHOLE
	                                mv $bluray_output_dir/$bluray_title.$bluray_extension $bluray_blackhole_dir/$bluray_title.$bluray_extension >> $global_log_dir/bluray-encode.log
 	                                # LOG : MOVED ENCODED BLURAY TO BLACKHOLE
		                        echo "$(stamp) - MOVED:  $bluray_output_dir/$bluray_title.$bluray_extension --> $bluray_blackhole_dir/$bluray_title.$bluray_extension" >> $global_log_dir/bluray-encode.log
                	                chmod -R 777 $bluray_blackhole_dir
				fi
                        else
                                # LOG : RIPPED BLURAY WAS NOT BIGGER THAN THE MINIMUM FILESIZE EXPECTED
                                echo "$(stamp) - ERROR: $bluray_output_dir/$bluray_title.$bluray_extension ($bluray_actualsize) is under $bluray_minimumsize bytes" >> $global_log_dir/bluray-encode.log
                        fi
                else
        	        # LOG : RIPPED BLURAY WAS NEVER CREATED (ERROR WITH HANDBRAKE ENCODE)
	                echo "$(stamp) - ERROR: $bluray_output_dir/$bluray_title.$bluray_extension was never created" >> $global_log_dir/bluray-encode.log
                fi
                # LOG : COMPLETED ENCODE OF THIS BLURAY
		echo "*********************************  COMPLETING:  $bluray_title  *********************************" >> $global_log_dir/bluray-encode.log
        fi
done

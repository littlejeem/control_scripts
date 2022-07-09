# **"control_scripts"**

## Background

This is a collection of scripts used on a day to day basis to automate various functions on my media pc, specifically the ripping and encoding of my blu-ray and music collections.

The overall aim is to create a bunch of scripts that will provide the functionality that I (or my family) insert media into by optical drive, the content is ripped, encoded and available for use the way I want it.

This is very much a work in progress and started on the basis that I needed a project to help give me a reason to learn about bash scripting, I've wanted to be able to do something like this ever since I looked at Benjamin Bryan's https://b3n.org/automatic-ripping-machine/ while messing about with 'xbmc', now Kodi.

Anyone is welcome to use any part of these scripts while respecting the rights of the authors of various tools I use.

If you do use any of these scripts and come up with a problem, idea, improvement or just want to help me learn, just let me know.

NOTE: There are tools out there that do this a bunch better than these scripts or I can come close to, namely "ACE - Encode" Project here: https://joelbassett.github.io/ace-encode/

-------------------------------------------------------------------------------------------------

## **TL;DR**

### Setting Up
Clone the repository onto your machine, along with the helper_script repository, eg:

```bash
cd ~/bin
git clone https://github.com/littlejeem/control_scripts.git
git clone https://github.com/littlejeem/standalone_scripts.git
cd control_scripts
git checkout develop
```

### Installation

install options are available via the ```-h flag```

```bash
cd ~/bin
./control_scripts_install.sh -h
```

```
Usage: /home/jlivin25/bin/control_scripts/control_scripts_install.sh control_scripts_install.sh
Usage: /home/jlivin25/bin/control_scripts/control_scripts_install.sh -V selects dry-run with verbose level logging
	-d Use this flag to specify dry run, no files will be converted, useful in conjunction with -V or -G 
	-S Override set verbosity to specify silent log level
	-V Override set verbosity to specify Verbose log level
	-G Override set verbosity to specify Debug log level
	-p Specifically choose to install postfix prior to attempting to install abcde as its a requirement
	-u Use this flag to specify a user to install scripts under, eg. user foo is entered -u foo
	   As I made these scripts for myself the defualt user is my own
	-g Use this flag to specify a usergroup to install scripts under, eg. group bar is entered -g bar, combined with the -u flag.
	   These settings will be used as: chown foo:bar. As i made these scripts for myself the defualt group is my own
	-d Use this flag to specify the identity of the CD/DVD/BLURAY drive being used, eg. /dev/sr1 is entered -d sr1, sr0 will be the assumed default 
	 Running the script with no flags causes default behaviour with logging level set via 'verbosity' variable
	-h -H Use this flag for help
```

run install script eg:

```bash
cd ~/bin
./control_scripts_install.sh
```

Insert disk and off you go.

--------------------------------------------------------------------------------------------------------------------------------------------------------

## **Known Bugs**
https://github.com/littlejeem/control_scripts/issues/18 - systemd / journal seems to drop lines from its 'status' log, don't know why. More research is needed


## Ripping Scripts

### DVD_Ripping.sh

WORK IN PROGRESS

### CD_Ripping.sh

WORK IN PROGRESS

### BD_Ripping.sh

This script has been written to automate the use of the fabulous tools makemkv and HandBrake, it uses makemkv to rip the disc content and HandBrake to encode it, presently this only works for blu-ray films

The aim of the script is to automate ripping & encoding of a bluray. Open drive -> put disk in -> close drive -> off it goes

The script has been written so that it can be run automatically using UDEV and a systemd service but it can also be run independently from the command line, either called directly from terminal/ssh or by running ```sudo systemctl start BD_ripping.service```

#### Usage

Usage options are available via '-h' flag

```bash
./BD_ripping.sh -h
```

```
Usage: /home/jlivin25/bin/full_script.sh
Usage: /home/jlivin25/bin/full_script.sh -G -r -t ## -l "FILE SOURCE LOCATION" -q ## -n ## -s -c
Usage: /home/jlivin25/bin/full_script.sh -G -e -t 36 -l "my awesome blu-ray source directory" -q 18 -n 20 -s -c
	 Running the script with no flags causes default behaviour with logging level set via 'verbosity' variable
	-S Override set verbosity to specify silent log level
	-V Override set verbosity to specify Verbose log level
	-G Override set verbosity to specify Debug log level
	-h -H Use this flag for help
	-r Rip Only: Will cause the script to only rip the disc, not encode. NOTE: -r & -e cannot both be set
	-e Encode Only: Will cause the script to encode to container only, no disc rip. NOTE: -r & -e cannot both be set
	-s Source delete override: By default the script removes the source files on completion. Selecting this flag will keep the files
	-p Disable the progress bars in the script visible in terminal, useful when debugging rest of script
	-c Temp Override: By default the script removes any temp files on completion. Selecting this flag will keep the files, useful if debugging
	-t Manually provide the title to rip eg. -t 42
	-n Provide a niceness value to run intensive (HandBrake) tasks under, useful if machine is used for multiple things
	-o Manually provide the feature name to lookup online eg. -o "BETTER TITLE", useful for those discs that aren't helpfully named.
	   eg: disc name is LABEL_1 but you want online data for 13 Assassins, you'd use -n "13 Assassins" as the entry
	-l Manually override the default location used for encoding source files, defaut is usually the output folder from Rip.
	-q Manually provide the quality to encode in handbrake, eg. -q 21. default value is 19, anything lower than 17 is considered placebo
```

There are three main methods of using this script.

1: (preferred) Using the installed defaults of UDEV rule -> calling ripping service -> calling ripping script.

2: No UDEV and running the script by starting the ripping service

3: Running script directly from command line prompt

More detail on these options are listed below.

#### 1: Default Automatic Action

Insert the disk and wait until the script finishes, done. you can check on progress as detailed in 'Getting Progress Info' section.

#### 2: Using systemd

As described above, using the script after first installing with the installation file allows running via systemctl. This allows the script to run in the background and be managed by systemd.

This means that once you eject the disk drive, load a disk and close the tray UDEV rules installed by the install script trigger the service and carry's out the chosen actions for the disk.

However if you either choose to disable the UDEV rules or if the disk is in the drive and you want to interact with the script you can trigger the script via command line.

To start the script:
```
sudo systemctl start BD_ripping.service
```

To stop the script:
```
sudo systemctl stop BD_ripping.service
```

#### 3: Command Line

Run the script by using...

```./BD_ripping.sh```

...in the install directory.

You can add various flags to alter the command line behaviour as

###### default (no flags) ######
Logging level is set to 4 (notify), progress bars will be shown,


#### Getting Progress Info ####

If running in command line, say using screen, then the script will report progress as defined by the flags chosen.

If allowing the script to run automatically you can check on the script progress, say by logging in via .ssh, and running either.

```
sudo systemctl -l --no-pager status BD_ripping.service --full
```

Or
```
grep BD_ripping.sh /var/log/syslog
```

Example output from ```systemctl status``` would be:
```
example_user@kodiminimal:~$ sudo systemctl -l --no-pager status BD_ripping.service --full
● BD_ripping.service - BD Ripping Service
   Loaded: loaded (/etc/systemd/system/BD_ripping.service; disabled; vendor preset: enabled)
   Active: active (running) since Sat 2022-05-21 09:00:36 BST; 4h 21min ago
 Main PID: 32681 (bash)
    Tasks: 30 (limit: 4915)
   CGroup: /system.slice/BD_ripping.service
           ├─ 7915 HandBrakeCLI --json --no-dvdna -i /home/example_user/Videos/Rips/blurays/BIG_BUCK -t 9 -o /home/example_user/Videos/Encodes/blurays/Big Buck Bunny (2008)/Big Buck Bunny (2008) - Bluray-1080p_Proper - DTS-HD.mkv -f mkv -e x264 --encoder-preset medium --encoder-tune film --encoder-profile high --encoder-level 4.1 -q 19.0 -2 -a 2 -E copy --audio-copy-mask dtshd,truehd,dts --crop 0:0:0:0 --loose-anamorphic --keep-display-aspect --modulus 2 --decomb -N eng -F scan
           ├─20748 sleep 40m
           └─32681 bash /home/example_user/bin/BD_ripping.sh -c

May 21 09:00:36 example_system systemd[1]: Started BD Ripping Service.
May 21 09:00:36 example_system example_user[32724]: [BD_ripping.sh] full_script started
May 21 09:30:51 example_system example_user[2919]: [BD_ripping.sh] NOTICE -- Ripping at: 25%
May 21 09:45:51 example_system example_user[4094]: [BD_ripping.sh] NOTICE -- Ripping at: 40%
May 21 11:13:12 example_system example_user[11374]: [BD_ripping.sh] NOTICE -- Encoding... 10%
May 21 11:53:12 example_system example_user[14371]: [BD_ripping.sh] NOTICE -- Encoding... 15%
May 21 12:33:12 example_system example_user[17476]: [BD_ripping.sh] NOTICE -- Encoding... 30%
```

An example output from the grep method, using defaults would be:

```
May 21 09:00:36 example_system example_user: [BD_ripping.sh] full_script started
May 21 09:00:36 example_system example_user: [BD_ripping.sh] NOTICE -- Ripping started...
May 21 09:00:51 example_system example_user: [BD_ripping.sh] NOTICE -- Ripping at: 1%
May 21 09:15:51 example_system example_user: [BD_ripping.sh] NOTICE -- Ripping at: 10%
May 21 09:30:51 example_system example_user: [BD_ripping.sh] NOTICE -- Ripping at: 25%
May 21 09:45:51 example_system example_user: [BD_ripping.sh] NOTICE -- Ripping at: 40%
May 21 10:00:51 example_system example_user: [BD_ripping.sh] NOTICE -- Ripping at: 60%
May 21 10:15:51 example_system example_user: [BD_ripping.sh] NOTICE -- Ripping at: 90%...nearly done
May 21 10:30:51 example_system example_user: [BD_ripping.sh] NOTICE -- ...ripping complete
May 21 10:31:01 example_system example_user: [BD_ripping.sh] WARNING -- NO AC3 tracks detected, error??
May 21 10:31:02 example_system example_user: [BD_ripping.sh] NOTICE -- Encoding started...
May 21 11:13:12 example_system example_user: [BD_ripping.sh] NOTICE -- Encoding... 10%
May 21 11:53:12 example_system example_user: [BD_ripping.sh] NOTICE -- Encoding... 15%
May 21 12:33:12 example_system example_user: [BD_ripping.sh] NOTICE -- Encoding... 30%
May 21 14:35:13 example_system example_user: [BD_ripping.sh] NOTICE -- Encoding... 60%
May 21 15:15:13 example_system example_user: [BD_ripping.sh] NOTICE -- Encoding... 60%
May 21 15:55:13 example_system example_user: [BD_ripping.sh] NOTICE -- Encoding... 75%
May 21 16:35:13 example_system example_user: [BD_ripping.sh] NOTICE -- Encoding... 75%
May 21 17:15:13 example_system example_user: [BD_ripping.sh] NOTICE -- Encoding of Big Buck Bunny (2008) complete.
May 21 17:15:14 example_system example_user: [BD_ripping.sh] NOTICE -- successfully removed lockdirectory
May 21 17:15:14 example_system example_user: [BD_ripping.sh] full_script completed
```

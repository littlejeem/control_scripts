# control_scripts

## Background

This is a collection of scripts used on a day to day basis to automate various functions on my media pc, specifically the ripping and encoding of my blu-ray and music collections.

The overall aim is to create a bunch of scripts that will provide the functionality that I (or my family) insert media into by optical drive, the content is ripped, encoded and availiable for use the way I want it.

This is very much a work in progress and started on the basis that I needed a project to help give me a reason to learn about bash scripting, I've wanted to be able to do something like this every since i looked at Benjamin Bryan's https://b3n.org/automatic-ripping-machine/ while messing about with KODI

Anyone is welcome to use any part of these scripts while respecting the rights of the authors of various tools i use.

If you do use any of these scripts and come up with a problem, idea, improvement or just want to help me learn, just let me know.

-------------------------------------------------------------------------------------------------

## TL;DR

### **Setting Up**
Clone the repository onto your machine, along with the helper_script repository, eg:

```bash
cd ~/bin
git clone https://github.com/littlejeem/control_scripts.git
git clone https://github.com/littlejeem/standalone_scripts.git
cd control_scripts
git checkout develop
```

### **Installation**

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
	-u Use this flag to specify a user to install scripts under, eg. user foo is entered -u foo, as i made these scripts for myself the defualt user is my own
	-g Use this flag to specify a usergroup to install scripts under, eg. group bar is entered -g bar, combined with the -u flag these settings will be used as: chown foo:bar. As i made these scripts for myself the defualt group is my own
	-d Use this flag to specify the identity of the CD/DVD/BLURAY drive being used, eg. /dev/sr1 is entered -d sr1, sr0 will be the assumed default
	 Running the script with no flags causes default behaviour with logging level set via 'verbosity' variable
	-h -H Use this flag for help
```


run install script eg:

```bash
cd ~/bin
./control_scripts_install.sh
```

## **BD_ripping.sh**

This script has been written to automate the use of the fabulous tools makemkv and HandBrake, it uses makemkv to rip the disc content and HandBrake to encode it, presently this only works for blu-ray films

The script has been written so that it can be run automatically using UDEV and a systemd service but it can also be run independantly from the commandline

Usage options are availiable via '-h' flag

```bash
./BD_ripping.sh -h
```

```
Usage: /home/USER/bin/control_scripts/ripping_scripts/BD_ripping.sh BD_ripping.sh -G -e -t ## -n TITLE HERE -q ## -s -c
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
	-n Manually provide the feature name to lookup eg. -n BETTER TITLE, useful for those discs that aren't helpfully named
	-q Manually provide the quality to encode in handbrake, eg. -q 21. default value is 19, anything lower than 17 is considered placebo
```

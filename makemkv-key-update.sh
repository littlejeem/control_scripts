#!/bin/bash
#
#
#############################################################
### A script to automatically update the key MakeMKV beta ###
#############################################################
FILE_LOC=/home/jlivin25/.MakeMKV/settings.conf
#URL='https://www.makemkv.com/forum/viewtopic.php?t=1053'
URLCONTENT=$(wget https://www.makemkv.com/forum/viewtopic.php?t=1053 -q -O -)
#KEY="`lynx -source $URL | grep 'codecontent">' | cut -d \> -f11 | sed 's/<\/div$//'`"
KEY=echo "$URLCONTENT" | grep -o -P '(?<=<code>).*(?=</code>)'
echo $KEY
sed -i "s|^app_Key.*|${KEY}|" /home/jlivin25/.MakeMKV/settings.conf

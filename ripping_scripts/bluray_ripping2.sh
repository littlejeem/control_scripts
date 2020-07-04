#!/bin/bash
source_drive="disc:0"
dev_drive="/dev/sr0"
working_dir="/home/jlivin25"
rip_dest="Rips/bluray"
bluray_name=$(blkid -o value -s LABEL "$source_drive")
bluray_name=${bluray_name// /_}
makemkvcon backup "$source_drive" "$working_dir"/"$rip_dest"/"$bluray_name"

#!/bin/bash
source_drive="/dev/sr0"
bluray_name=$(blkid -o value -s LABEL "$source_drive")
bluray_name=${bluray_name// /_}

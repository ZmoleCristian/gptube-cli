#!/bin/bash
# This script will install the required packages for the script to run

# check root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

#gets the package manager and define a variable for it to be used later and sets the names of the packages according to the package manager
if [ -f /usr/bin/apt-get ]; then
  PM="apt-get"
  PM_INSTALL="install"
  PM_PACKAGES="jq curl ffmpeg libmp3lame0"
  PM_YES="-y"
elif [ -f /usr/bin/yum ]; then
  PM="yum"
  PM_INSTALL="install"
  PM_PACKAGES="jq curl ffmpeg"
  PM_YES="-y"
elif [ -f /usr/bin/pacman ]; then
  PM="pacman"
  PM_INSTALL="-S"
  PM_PACKAGES="jq curl ffmpeg lame"
  PM_YES="--noconfirm --needed"

else
  echo "No compatible package manager found"
  exit 1
fi
#download latest version of yt-dlp
wget -qO /usr/local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp

#installs the packages
$PM $PM_INSTALL $PM_PACKAGES $PM_YES
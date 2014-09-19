#!/bin/bash

# The purpose of this file is to upgrade your ubuntu instance with out upgrading to the next major version.
# To upgrade a whole major version, use "dist-upgrade" instead of "upgrade"
# Since the script installs postgresql through the apt-get process, the apt-get upgrade should also install security patches as well.
#  - I have not absolutely confirmed the above statement.

# References:
#  http://debian-handbook.info/browse/wheezy/sect.apt-get.html
#  http://askubuntu.com/questions/146921/how-do-i-apt-get-y-dist-upgrade-without-a-grub-config-prompt

unset UCF_FORCE_CONFFOLD
export UCF_FORCE_CONFFNEW=YES
ucf --purge /boot/grub/menu.lst

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -o Dpkg::Options::="--force-confnew" --force-yes -fuy upgrade
#!/bin/bash

USER_TO_ADD=$1
sudo adduser $USER_TO_ADD --disabled-password --gecos "$USER_TO_ADD,none,none,none"

# create user credential in the tmp directory
TEMP_DIR=/tmp/"$USER_TO_ADD".pem
mkdir -p $TEMP_DIR
cd $TEMP_DIR
sudo ssh-keygen -f $USER_TO_ADD -N ''
# rename pem file
sudo mv $USER_TO_ADD $USER_TO_ADD.pem

# make you the current user the owner of these files so you can download .pem later via scp
sudo chown -R $USER:$USER $TEMP_DIR

sudo -u $USER_TO_ADD mkdir /home/$USER_TO_ADD/.ssh
sudo chmod 700 /home/$USER_TO_ADD/.ssh
sudo -u $USER_TO_ADD cat $TEMP_DIR/$USER_TO_ADD.pub | sudo tee --append /home/$USER_TO_ADD/.ssh/authorized_keys
sudo chmod 600 /home/$USER_TO_ADD/.ssh/authorized_keys
sudo chown $USER_TO_ADD:$USER_TO_ADD /home/$USER_TO_ADD/.ssh/authorized_keys

mv $TEMP_DIR /home/$USER/.
rm /home/$USER/"$USER_TO_ADD".pem/*.pub

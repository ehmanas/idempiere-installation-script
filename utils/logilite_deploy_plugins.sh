#!/bin/bash
#

usage()
{
cat << EOF

usage: $0

This script helps you launch the appropriate iDempiere Plug-Ins/components on a given server

OPTIONS:
    -h  Help
    -I  (1) No Install/Update plug-ins (2) Start plug-ins (3) Restart iDempiere
    -S  (1) Install/Update plug-ins (2) Not Start plug-ins (3) Restart iDempiere
    -R  (1) Install/Update plug-ins (2) Start plug-ins (3) No Restart iDempiere
    -m  Also installed/Update plugins, which is already installed on server.
    -D  Will not delete source jar.
EOF
}

echo "You are about to update your system - you have 10 seconds to press ctrl+c to stop this script"
sleep 10

#pull in variables from properties file
#NOTE: all variables starting with CHUBOE_PROP... come from this file.
SCRIPTNAME=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPTNAME")
source $SCRIPTPATH/chuboe.properties

#initialize variables with default values - these values might be overwritten during the next section based on command options
IS_INSTALL_PLUGINS="Y"
IS_START_PLUGINS="Y"
IS_ID_RESTART="Y"
SKIP_DEPLOYED_PG="Y"
IS_DELETE_FROM_SCAN="Y"
PLUGINS_SCAN_PATH="$CHUBOE_PROP_DEPLOY_PLUGINS_PATH"
CUSTOM_PLUGINS_PATH="$CHUBOE_PROP_CUSTOM_PLUGINS_PATH"
IDEMPIERE_USER="$CHUBOE_PROP_IDEMPIERE_OS_USER"
IDEMPIERE_PATH="$CHUBOE_PROP_IDEMPIERE_PATH"
CHUBOE_UTIL_HG="$CHUBOE_PROP_UTIL_HG_PATH"

# Create a backup of the iDempiere folder before deployed plugins
cd $CHUBOE_UTIL_HG/utils/
./chuboe_hg_bindir.sh

# process the specified options
# the colon after the letter specifies there should be text with the option
# NOTE: include u because the script previously supported a -u OSUser
while getopts ":hISRmD" OPTION
do
    case $OPTION in
        h)  usage
            exit 1;;

        I)  IS_INSTALL_PLUGINS="N";;

        R)  IS_START_PLUGINS="N";;

        S)  IS_ID_RESTART="N";;

        m)  SKIP_DEPLOYED_PG="N";;

        D)  IS_DELETE_FROM_SCAN="N";;

        # Option error handling.
        \?) valid=0
            echo "HERE: An invalid option has been entered: $OPTARG"
            exit 1
            ;;

        :)  valid=0
            echo "HERE: The additional argument for option $OPTARG was omitted."
            exit 1
            ;;

    esac
done

# show variables to the user (debug)
echo "Install Plugins" $IS_INSTALL_PLUGINS
echo "Plugis start" $IS_START_PLUGINS
echo "Plugins Source Dir"=$PLUGINS_SCAN_PATH
echo "Target customization plugins dir"=$CUSTOM_PLUGINS_PATH
echo "iDempiere user"=$IDEMPIERE_USER
echo "iDempiere Path"=$IDEMPIERE_PATH
echo "HERE: Distro details:"
cat /etc/*-release

# Save plugins inventory in file.
sudo su $IDEMPIERE_USER -c "./chuboe_osgi_ss.sh &> $IDEMPIERE_PATH/plugins-list.txt &"

# Wait for a moment to generate plugins-list.txt inventory file.
sleep 4

if [[ $IS_INSTALL_PLUGINS == "Y" ]]
then

    # Checking deploy-jar folder exist or not.
    if [ -d "$PLUGINS_SCAN_PATH" ]; then
        echo "$PLUGINS_SCAN_PATH Directory Exist"
    else
        echo "Please create Directory deploy-jar under $IDEMPIERE_PATH and copy your all jar in same folder."
        exit 0
    fi
    
    # Checking plugins locate or not in deploy-jar
    if ls $PLUGINS_SCAN_PATH/*.jar 1> /dev/null 2>&1; then
        echo "Found vailid plug-In in $PLUGINS_SCAN_PATH"
    else
        echo "Could not found any plug-In in $PLUGINS_SCAN_PATH"
        exit 0
    fi

    # make sure all plugins files are owned by iDempiere before we start
    sudo chown -R $IDEMPIERE_USER:$IDEMPIERE_USER $PLUGINS_SCAN_PATH

    # Checking customization-jar folder exist or not.
    if [ -d "$CUSTOM_PLUGINS_PATH" ]; then
        echo "$CUSTOM_PLUGINS_PATH Directory Exist"
    else
        sudo -u $IDEMPIERE_USER mkdir $CUSTOM_PLUGINS_PATH
    fi


    if ps aux | grep java | grep $IDEMPIERE_PATH > /dev/null
    then
        echo "idempiere service is running"
    else
        echo "idempiere service is not running, So please start idempiere service and try again."
        exit 0
    fi


    #### Array Configuration Start ####
    plugins=$(ls $PLUGINS_SCAN_PATH/ | grep .jar)
    str="$plugins"
    delimiter=\n
    strLen=${#str}
    counter=0
    dLen=${#delimiter}
    i=0
    wordLen=0
    strP=0
    array=()
    while [ $i -lt $strLen ]; do
        if [ $delimiter == '${str:$i:$dLen}' ]; then
            array+=(${str:strP:$wordLen})
            strP=$(( i + dLen ))
            wordLen=0
            i=$(( i + dLen ))
        fi
        i=$(( i + 1 ))
        wordLen=$(( wordLen + 1 ))
    done
    array+=(${str:strP:$wordLen})

    for plugins in "${array[@]}"
    do
        echo " "
        echo " "
        echo "********************************************"
        echo "We're Deploying: $plugins"

        PLUGIN_NAME=$(ls $PLUGINS_SCAN_PATH/ | grep "$plugins" | cut -d '_' -f 1 | sed 's/$/_/')
        PLUGIN_NAME_WITHOUT_VERSION=$(ls $PLUGINS_SCAN_PATH/ | grep "$plugins" | cut -d '_' -f 1)
        PLUGIN_NAME_WITH_VERSION=$(ls $PLUGINS_SCAN_PATH/ | grep "$plugins" | sed 's/.\{4\}$//')

        # Checking, Same version plugin already installed or not,
        # If already installed same verseion plugin then skip and continue with next one.
        if [[ $SKIP_DEPLOYED_PG == "Y" ]]
        then          
            CHECKING_PLUGIN=
            checkingplugin() {
                CHECKINGPLUGINSTRING=$(grep -n "$PLUGIN_NAME_WITH_VERSION" $IDEMPIERE_PATH/plugins-list.txt)
                CHECKING_PLUGIN=$?
            }
            
            checkingplugin
            if [ $CHECKING_PLUGIN -eq 0 ];
            then
                echo "Same plugins already deployed in iDempiere, So skip that plugin."
                continue
            fi
        fi

        # Check plugin already installed or,
        # If already installed plugin with older version then update that plugin or plugin is not installed on server then it will going to install.
        PlUGINSTATUS=
        getpluginstatus() {
            PLUGINSTATUSSTRING=$(grep -n "$PLUGIN_NAME" $IDEMPIERE_PATH/plugins-list.txt)
            PlUGINSTATUS=$?
        }

        getpluginstatus
        if [ $PlUGINSTATUS -eq 0 ];
        then
            echo "Plugin $plugins exist..."

            sudo su $IDEMPIERE_USER -c "./chuboe_osgi_ss.sh &> /tmp/plugins-list-exist-$PLUGIN_NAME.txt &"
            sleep 2
            EXIST_PLUGIN_ID=$(cat /tmp/plugins-list-exist-$PLUGIN_NAME.txt | grep $PLUGIN_NAME | cut -f 1)
            
            Startlevel_CSV="$SCRIPTPATH/logilite_plugins_startlevel.csv"
            if [ -f "$Startlevel_CSV" ]; then
                START_LEVEL=$(cat $SCRIPTPATH/logilite_plugins_startlevel.csv | grep $PLUGIN_NAME_WITHOUT_VERSION | cut -d ',' -f 2)
            fi
            
            echo "Plugin $EXIST_PLUGIN_ID ID of existing $plugins"

            sudo -u $IDEMPIERE_USER cp -r $PLUGINS_SCAN_PATH/$plugins $CUSTOM_PLUGINS_PATH/
            ./logilite_telnet_update.sh $CUSTOM_PLUGINS_PATH/$plugins $EXIST_PLUGIN_ID $START_LEVEL
            counter=$((counter + 1))

            echo "Plugin $plugins installed successfully."
            echo "********************************************"
            echo " "
            echo " "

        else

            echo "Plugin $plugins not exist..."

            sudo -u $IDEMPIERE_USER cp -r $PLUGINS_SCAN_PATH/$plugins $CUSTOM_PLUGINS_PATH/
            ./logilite_telnet_install.sh $CUSTOM_PLUGINS_PATH/$plugins
            sleep 1

            sudo su $IDEMPIERE_USER -c "./chuboe_osgi_ss.sh &> /tmp/plugins-list-exist-$PLUGIN_NAME.txt &"
            sleep 2
            PLUGIN_ID=$(cat /tmp/plugins-list-exist-$PLUGIN_NAME.txt | grep $PLUGIN_NAME | cut -f 1)
            echo "Plugin $PLUGIN_ID ID of $PLUGIN_NAME"

            Startlevel_CSV="$SCRIPTPATH/logilite_plugins_startlevel.csv"
            if [ -f "$Startlevel_CSV" ]; then
                START_LEVEL=$(cat $SCRIPTPATH/logilite_plugins_startlevel.csv | grep $PLUGIN_NAME_WITHOUT_VERSION | cut -d ',' -f 2)
            fi
            
            ./logilite_telnet_set_bundlelevel.sh $PLUGIN_ID $START_LEVEL
            counter=$((counter + 1))

            echo "$plugins installed successfully."
            echo "********************************************"
            echo " "
            echo " "
        fi
    done
fi

if [[ $IS_ID_RESTART == "Y" ]]
then
    echo "Here: Restarting iDempiere Service"
    sudo service idempiere restart
    echo "iDempiere Service Restarted Successfully"
    sleep 10
fi

if [[ $IS_START_PLUGINS == "Y" ]]
then
       
    PLUGINS_LIST=$(ls $PLUGINS_SCAN_PATH/ | grep .jar | cut -d '_' -f 1 | sed 's/$/_/')
    strp="$PLUGINS_LIST"
    delimiterp=\n
    strLenp=${#strp}
    dLenp=${#delimiterp}
    p=0
    wordLenp=0
    strPp=0
    array=()
    while [ $p -lt $strLenp ]; do
        if [ $delimiterp == '${strp:$p:$dLenp}' ]; then
            array+=(${strp:strPp:$wordLenp})
            strPp=$(( p + dLenp ))
            wordLenp=0
            p=$(( p + dLenp ))
        fi
        p=$(( p + 1 ))
        wordLenp=$(( wordLenp + 1 ))
    done
    array+=(${strp:strPp:$wordLenp})

    for plugunselement in "${array[@]}"
    do
        echo " "
        echo "********************************************"
        sudo su $IDEMPIERE_USER -c "./chuboe_osgi_ss.sh &> /tmp/plugins-list-exist-"$plugunselement"-id.txt &"
        sleep 2
        JAR_BUNDLE_ID=$(cat /tmp/plugins-list-exist-"$plugunselement"-id.txt | grep $plugunselement | cut -f 1)
        echo "Update/Install Plugin ID"="$JAR_BUNDLE_ID"
        ./logilite_telnet_start.sh $JAR_BUNDLE_ID
        sleep 1
        
        sudo su $IDEMPIERE_USER -c "./chuboe_osgi_ss.sh &> /tmp/plugins-list-exist-"$plugunselement"-status.txt &"
        sleep 2
        JAR_BUNDLE_STATUS=$(cat /tmp/plugins-list-exist-"$plugunselement"-status.txt | grep $plugunselement | cut -d " " -f 1 | cut -f 2)
        echo "Status of $plugunselement is"="$JAR_BUNDLE_STATUS"
        echo "********************************************"
        echo " "
    done

fi

if [[ $IS_INSTALL_PLUGINS == "Y" ]]
then
    # Remove plugins list and deployed jar from deploy-jar folder
    if [[ $IS_DELETE_FROM_SCAN == "Y" ]]
    then
        sudo rm -rf $PLUGINS_SCAN_PATH/*.jar
    fi
    
    sudo rm -rf /tmp/plugins*
    sudo su $IDEMPIERE_USER -c "./chuboe_osgi_ss.sh &> $IDEMPIERE_PATH/plugins-list.txt &"
    
    # wait 10 seconds for the deployment to finish before taking a backup
    sleep 10

    # Create a backup of the iDempiere folder after deployed plugins
    cd $CHUBOE_UTIL_HG/utils/
    ./chuboe_hg_bindir.sh

    # Change idempiere-server folder permission to avoid any conflict.
    # CHUCK: this should not be necessary and it is potentially dangerous in that it can mask issues.
    #sudo chown -R $IDEMPIERE_USER:$IDEMPIERE_USER $IDEMPIERE_PATH

    echo "##############################################################################################"
    echo $counter "Plugins is deployed, Please verify plugins status in $IDEMPIERE_PATH/plugins-list.txt"
    echo "##############################################################################################"
fi
#!/bin/sh

gSsidFile=/tmp/current.ssid
gWpaLogFile=/tmp/wpa.log

#
# Check wpa_supplicant service enable or not
#
# param[in]: none.
#
# return  Enable, zero is returned.
#         Disable, others is returned.
#
WpaS_iIsEnable()
{
    local ret=`systemctl is-enabled wpa_supplicant`
    if [ "$ret" != "masked" ]; then
        return 0
    fi

    return 1
}

#
# To disable wpa_supplicant service
#
# param[in]: none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
WpaS_iDisable()
{
    #local ret=`nmcli radio wifi`
    #if [ "$ret" != "disabled" ]; then
    #fi
    
    nmcli radio wifi off
    systemctl stop wpa_supplicant
    
    systemctl mask wpa_supplicant
    ExitIfError $? "Disable wpa_supplicant failed!"

    return 0
}

#
# To record SSID in temp file
#
# param[in] $1: the string of SSID.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
WpaS_iRecordSsid()
{
    local ssid="$1"

    if [ -z "$ssid" ]; then
        return 1
    fi

    echo "$ssid" > $gSsidFile
    if [ $? -eq 0 ]; then
        return 0
    fi

    return 2
}

#
# Get the current SSID from temp file
#
# param[in]: none.
# param[out] gRetStr: the string of SSID.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
WpaS_iGetCurSsid()
{
    if [ ! -e $gSsidFile ]; then
        return 1
    fi

    gRetStr=`cat $gSsidFile`
    if [ $? -eq 0 ]; then
        return 0
    fi

    return 2
}

#
# Run the wpa_supplicant in background 
#
# param[in] $1: the path to find the configuration of wpa_supplicant.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
WpaS_iRunSupplicant()
{
    CfgFile="$1"

    if [ ! -e $CfgFile ]; then
        return 1
    fi

    ps ax | grep -w 'wpa_supplicant' | awk '{print $5}' | grep "^wpa_supplicant$" > /dev/null
    if [ $? -ne 0 ]; then
        rfkill unblock wifi
        if [ $? -ne 0 ]; then
            return 2
        fi

        wpa_supplicant -ddd -B -i $iface -c $CfgFile -t -f $gWpaLogFile
        if [ $? -eq 0 ]; then
            return 0
        else
            return 3
        fi
    fi

    return 0
}

#
# Stop the wpa_supplicant
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
WpaS_iStopSupplicant()
{
    ps ax | grep -w 'wpa_supplicant' | awk '{print $5}' | grep "^wpa_supplicant$" > /dev/null
    if [ $? -eq 0 ]; then
        killall wpa_supplicant
        if [ $? -eq 0 ]; then
            return 0
        else
            return 1
        fi
    fi

    return 0
}

#
# Setting with roaming.
#
# param[in] $1: the string of wireless interface.
#           $2: the number of RSSI thresold.
#           $3: the number of short interval scan.
#           $4: the number of long interval scan.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
WpaS_iSetRoam()
{
    if [ -z $1 ] || [ -z $2 ] || [ -z $3 ] || [ -z $4 ]; then
        return 1
    fi

    iface="$1"
    thresold=$2
    short=$3
    long=$4

    #
    # The format of command
    # wpa_cli -i wlp3s0 set_network 0 bgscan '"simple:5:-65:10"'
    # wpa_cli -i wlan0 reassociate
    #
    local setting="simple:$short:$thresold:$long"
    Dbg "Take affect with roaming \"$setting\""

    wpa_cli -i $iface set_network 0 bgscan "\"${setting}\""
    if [ $? -ne 0 ]; then
        return 2
    fi

    Dbg "Take effect from roaming setting"
    wpa_cli -i $iface reassociate
    if [ $? -ne 0 ]; then
        return 3
    fi

    return 0
}


# 
# Template
#
# param[in]: none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
#WpaS_()
#{

#}

#!/bin/sh

#
# Global variables
#
gSDir_MbimScript="$gTopdir/driver/common/app/mbim-set-ip"

#
# Marcos
#
RADIO_ON="on"
RADIO_KEEP_ON="keep_on"
RADIO_OFF="off"

#
# Check the state of registration with MBIM
#
# param[in] $1: the device node.
#               (i.g. /dev/cdc-wdm0)
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Mbim_iCheckReg()
{
    local node=$1
    local ret;

    [ -z $node ] && return 1

    ret=`mbimcli -p --query-registration-state "--device=${node}" | grep "Register state" | cut -d: -f2 | sed "s/ //g" | sed "s/'//g"`

    # debug
    echo "MBIM-[$(date +%Y%m%d-%H%M%S)] $ret" >> /tmp/mbim.log
    
    if [ "$ret" = "home" ]; then
        return 0
    else
        return 2
    fi
}

#
# Disconnection with MBIM
#
# param[in] $1: the device node.
#               (i.g. /dev/cdc-wdm0)
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Mbim_iDisConnect()
{
    local node=$1

    [ -z $node ] && return 1 

    mbim-network "$node" stop

    return $?
}

#
# Start MBIM network
#
# param[in] $1: the device node.
#               (i.g. /dev/cdc-wdm0)
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Mbim_iStart()
{
    local node=$1

    [ -z $node ] && return 1

    mbim-network "$node" start

    return $?
}

#
# Set IP address with MBIM network
#
# param[in] $1: the device node.
#               (i.g. /dev/cdc-wdm0)
# param[in] $2: the network interface.
#               (i.g. wwan0)
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Mbim_iSetIP()
{
    local node=$1
    local iface=$2

    [ -z $node ] && return 1
    [ -z $iface ] && return 2

    $gSDir_MbimScript/mbim-set-ip "$node" "$iface"

    return $?
}

#
# Set pin code
#
# param[in] $1: the device node.
#               (i.g. /dev/cdc-wdm0)
# param[in] $2: the string of pin code
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Mbim_iSetPinCode()
{
    local node=$1
    local pin=$2

    [ -z $node ] && return 1
    [ -z $pin ] && return 2

    mbimcli -d $node -p --enter-pin=$pin

    return $?
}

#
# Turn on radio
#
# param[in] $1: the device node.
#               (i.g. /dev/cdc-wdm0)
# param[out] gRetStr: the string of value.
#                     RADIO_ON or RADIO_OFF              
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Mbim_iTurnOnRadio()
{
    local node=$1
    local ret;

    [ -z $node ] && return 1

    ret=`mbimcli -d $node -p --query-radio-state | grep 'Software' | awk '{ printf $4 }'`
    if [ -z "$ret" ]; then
        return 2
    fi
    
    if [ "$ret" = "'on'" ]; then
        gRetStr="$RADIO_KEEP_ON"
        return 0
    fi

    if [ "$ret" = "'off'" ]; then
        mbimcli -d $node -p --set-radio-state=on
        if [ $? -eq 0 ]; then
            gRetStr="$RADIO_ON"
            return 0
        else    
            return 3
        fi
    fi

    return 4
}

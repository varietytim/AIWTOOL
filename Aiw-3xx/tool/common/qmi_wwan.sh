#!/bin/sh

#
# Global variables
#
gQmiLog="/tmp/qmi_wwan.log"
gQmiCmdLog="/tmp/qmi_wwan_cmd.log"

#
# Check the state of connected or disconnected with QMI WWAN
#
# param[in] $1: the device node.
#               (i.g. /dev/cdc-wdm0)
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Qmi_iCheckStatus()
{
    local node=$1
    local ret;

    [ -z $node ] && return 1

    #
    # Don't run the qmi-network status if status file not exist.
    #
    if [ ! -e "/tmp/qmi-network-state-`basename $node`" ];then
        return 2
    fi

    qmi-network "$node" status
    if [ $? -eq 0 ]; then
        ret=`qmi-network "${node}" status | grep "^Status" | awk '{print $2}'`
    fi

    # debug
    echo "QMI_WWAN-[$(date +%Y%m%d-%H%M%S)] $ret" >> /tmp/qmi_wwan.log
    
    if [ "$ret" = "connected" ]; then
        return 0
    else
        return 3
    fi
}

#
# Stop QMI WWAN network
#
# param[in] $1: the device node.
#               (i.g. /dev/cdc-wdm0)
# param[in] $2: the network interface.
#               (i.g. wwan0)
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Qmi_iStop()
{
    local node=$1
    local iface=$2

    [ -z $node ] && return 1
    [ -z $iface ] && return 2

    #
    # Don't run the qmi-network stop if status file not exist.
    #
    if [ ! -e "/tmp/qmi-network-state-`basename $node`" ];then
        return 0
    fi

    qmi-network "$node" stop
    if [ $? -ne 0 ]; then
        return $?
    fi
    
    ip -4 addr flush dev $iface
    
    return 0
}

#
# Flush cache file with  QMI WWAN network
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Qmi_iFlush()
{
    for file in $(ls /tmp/qmi-network-*  2> /dev/null); do
        rm $file
    done

    return 0
}

#
# Start QMI WWAN network
#
# param[in] $1: the device node.
#               (i.g. /dev/cdc-wdm0)
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Qmi_iStart()
{
    local node=$1

    [ -z $node ] && return 1

    qmi-network "$node" start 2> /dev/null

    return $?
}

#
# Set IP address with MBIM network
#
# param[in] $1: the device node.
#               (i.g. /dev/cdc-wdm0)
# param[in] $2: the network interface.
#               (i.g. wwan0)
# param[in] $3: the number of metric with default route gateway.
#               (i.g. 100)
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Qmi_iSetIP()
{
    local node=$1
    local iface=$2
    local metric=$3
    local ret ipaddr submask gateway pdns sdns mtu;

    [ -z $node ] && return 1
    [ -z $iface ] && return 2
    [ -z $metric ] && metric=101

    qmicli -d "$node" --wds-get-current-settings > $gQmiCmdLog
    if [ $? -ne 0 ]; then
        return 3
    fi

    ipaddr=`grep "IPv4 address" $gQmiCmdLog | awk '{print $3}'`
    submask=`grep "IPv4 subnet mask" $gQmiCmdLog | awk '{print $4}'`
    gateway=`grep "IPv4 gateway address" $gQmiCmdLog | awk  '{print $4}'`
    pdns=`grep "IPv4 primary DNS" $gQmiCmdLog | awk '{print $4}'`
    sdns=` grep "IPv4 secondary DNS" $gQmiCmdLog | awk '{print $4}'`
    mtu=` grep "MTU" $gQmiCmdLog | awk '{print $2}'`
    if [ -z $ipaddr ] || [ -z $submask ] || [ -z $gateway ] || [ -z $pdns ] || [ -z $sdns ] || [ -z $mtu ]; then
        return 4
    fi

    #
    # Setting with IP network
    #
    Dbg3 "ip link set $iface down"
    ip link set $iface down
    
    Dbg3 "ip addr flush dev $iface"
    ip addr flush dev $iface
    
    Dbg3 "ip link set $iface up"
    ip link set $iface up
    if [ $? -ne 0 ]; then
        return 5
    fi
    
    Dbg3 "ip addr add $ipaddr/$submask dev $iface broadcast +"
    ip addr add "$ipaddr/$submask" dev $iface broadcast +
    if [ $? -ne 0 ]; then
        return 6
    fi
    
    Dbg3 "ip route add default via $gateway dev $iface metric $metric"
    ip route add default via $gateway dev $iface metric $metric 
    if [ $? -ne 0 ]; then
        return 7
    fi
    
    Dbg3 "ip link set mtu $mtu dev $iface"
    ip link set mtu $mtu dev $iface
    
    Dbg3 "systemd-resolve -4 --interface=$iface --set-dns=$pdns"

    local ubuntu_ver=`cat /etc/lsb-release | grep -w "DISTRIB_RELEASE" | cut -d'=' -f2 | cut -d'.' -f1`
    if [ $? -eq 0 ] && [ ! -z $ubuntu_ver ]; then
        if [ $ubuntu_ver -ge 22 ]; then
            Dbg3 "Ubuntu version is greater than or equal 22.04"
            resolvectl -4 dns $iface $pdns
        else
            Dbg3 "Ubuntu version is less than 22.04"
            systemd-resolve -4 --interface=$iface --set-dns=$pdns
        fi
    fi


    ##################################################################################

    if [ $? -ne 0 ]; then
        return 8
    fi

    return 0
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
#Qmi_iSetPinCode()
#{
#    local node=$1
#    local pin=$2

#    [ -z $node ] && return 1
#    [ -z $pin ] && return 2

    #mbimcli -d $node -p --enter-pin=$pin

#    return $?
#}

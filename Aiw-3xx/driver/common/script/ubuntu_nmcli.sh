#!/bin/sh

#
# Disable auto connection with specific network interface
#
# param[in] $1: the string of network interface
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Nmcli_iDisableAutoConnect()
{
    [ -z $1 ] && return 1

    local iface="$1"
    local ret;

    iface=`nmcli -f GENERAL.CONNECTION device show "$iface" | cut -d':' -f2`
    iface=`echo -n $iface`

    ret=`nmcli connection show "$iface" | grep ipv4.method | cut -d":" -f2`
    ret=`echo -n $ret`


    if [ -z "$ret" ]; then
        return 2
    fi

    if [ "$ret" = "auto" ]; then
	nmcli con mod "$iface" ipv4.addresses "0.0.0.0" > /dev/null
	nmcli con mod "$iface" ipv4.method manual > /dev/null

        ret=$?
        if [ $ret -ne 0 ]; then
            return $ret
        fi
    fi

    ret=`nmcli connection show "$iface" | grep ipv6.method | cut -d":" -f2`
    ret=`echo -n $ret`


    if [ -z "$ret" ]; then
        return 2
    fi

    if [ "$ret" = "auto" ]; then    
	## disable IPV6 as well ....
	nmcli con mod "$iface" ipv6.addresses "fe80::0001/64" > /dev/null
	nmcli con mod "$iface" ipv6.method manual > /dev/null
	ret=$?
        if [ $ret -ne 0 ]; then
            return $ret
        fi

    fi

    ##2404 test####################
    # ret=`nmcli -f name,autoconnect c s |grep -w "$iface" | awk '{print $4}'`
    # if [ -z "$ret" ]; then
    #     return 2
    # fi

    # if [ "$ret" = "yes" ]; then
    #     nmcli con mod "$iface" connection.autoconnect no > /dev/null
    #     ret=$?
    #     if [ $ret -ne 0 ]; then
    #         return $ret
    #     fi
    # fi
    ######################


    return 0
}

#
# Enable auto connection with specific network interface
#
# param[in] $1: the string of network interface
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Nmcli_iEnableAutoConnect()
{
    [ -z $1 ] && return 1

    local iface="$1"
    local ret;

    ret=`nmcli -f name,autoconnect c s |grep -w "$iface" | awk '{print $2}'`
    if [ -z "$ret" ]; then
        return 2
    fi

    if [ "$ret" = "no" ]; then
        nmcli con mod $iface connection.autoconnect yes > /dev/null
        ret=$?
        if [ $ret -ne 0 ]; then
            return $ret
        fi
    fi

    return 0
}


#!/bin/sh

KEY_APN='Apn'
KEY_USBMODE='UsbMode'
KEY_PIN='Pin'
KEY_REGS='RegStat'
KEY_IP='Ip'
KEY_RSSI='Rssi'
KEY_CURMODE='CurrentMode'
KEY_PINLOCK='PinLock'
KEY_PDNS='PrimaryDns'
KEY_SDNS='SecondaryDns'
KEY_NETIFACE='NetInterface'



#
# Parser key and get value
#
# param[in] $1: the string to parser.
# param[in] $2: the string of key.
# param[in] $3: the delimiter.
# param[out] gRetStr: the string of value.
#
# return  On success, zero is returned.
#         On error, others.
#
Parser_KeyValue()
{
    local pstr="$1"
    local key="$2"
    local del="$3"

    if [ -z $pstr ] || [ -z $key ] || [ -z $del ]; then
        return 1
    fi

    local tmp=`echo "$pstr" | grep "$key" | cut -d"$del" -f2`
    if [ ! -z $tmp ]; then
        gRetStr=$tmp
        return 0
    fi

    return 2
}

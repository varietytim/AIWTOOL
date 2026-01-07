#!/bin/sh

#
# Import file
#
[ -e $gCommonDir/key_var.sh ] && . $gCommonDir/key_var.sh
[ -e $gToolCommonDir/key_var.sh ] && . $gToolCommonDir/key_var.sh
#-KEY_SSID='ssid'
#-KEY_BSSID='bssid'
#-KEY_ADDRESS='address'


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

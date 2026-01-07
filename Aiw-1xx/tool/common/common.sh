#!/bin/sh

ExitIfError()
{
    if [ $1 -ne 0 ]; then
        echo "err: $2"
        exit $1
    fi
}

Msg()
{
    echo "\033[33m$1\033[0m"
}

Echo()
{
    echo "$1"
}

Common_iIsInteger()
{
    case "${1#[+-]}" in
        (*[![:digit:]]*) return 1 ;;
        ('') return 1 ;;
        (*) return 0 ;;
    esac
}

Common_iFindNetInterface()
{
    [ -z $1 ] && return 1

    local tmp_file="/tmp/$1_rename"
    local iface="$1"
    local update="$2"
    local ret;
    local len;

    #
    # Parser the below format :
    # [   21.472544] GobiNet 1-1:1.4 enp0s20u1i4: renamed from usb0
    # [   28.048781] cdc_mbim 1-3:1.0 wwp0s20u3: renamed from wwan0
    #
    if [ ! -e $tmp_file ] || [ "$update" = 1 ]; then
        ret=`dmesg | grep "renamed from $iface" | tail -1 | sed 's/^\[.*] //g' |cut -d' ' -f3 | cut -d':' -f1 | sed 's/^ //g'`
        if  [ ! -z $ret ]; then
            echo "$ret" > $tmp_file
        else
            echo "$iface" > $tmp_file
        fi
    fi

    gRetStr=`cat $tmp_file`
    return 0
}

Common_iCheckNetIface()
{
    local ret;

    [ -z $1 ] && return 1

    ifconfig | grep -w "$1:" > /dev/null 2>&1
    ret=$?

    return $ret
}

Common_iGetNetIp()
{
    local ret;
    local iface="$1"

    [ -z "$iface" ] && return 1

    ret=`ifconfig "$iface" | grep -w "inet" | sed 's/^[ ]*//g' | cut -d' ' -f 2`
    if [ $? -eq 0 ]; then
        if [ ! -z $ret ]; then
            gRetStr="$ret"
            return 0
        fi
    fi

    return 2
}

#
# Check file whether exist or not
#
# param[in] $1: the path to find the file.
#
# return  Exist, zero is returned.
#         Not exist, 1 is returned.
#         On error, others is returned.
#
Common_iIsFileExist()
{
    [ -z $1 ] && return 2

    if [ ! -e "$1" ]; then
        return 1;
    else
        return 0;
    fi
}

#
# Check the user whether root or not
#
# param[in] none.
#
# return  Is root, zero is returned.
#         Not root, others is returned.
#
Common_iIsRoot()
{
    [ "$USER" = "root" ] && return 0

    #
    # This is special case with rc.local while booting
    #
    [ -z "$USER" ] && return 0

    return 1
}

#
# Check vendor ID and product ID
#
# param[in] $1: the string of vendor ID
# param[in] $2: the string of product ID
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Common_iCheckModuleID()
{
    local vendorId=$1
    local productId=$2

    if [ -z $vendorId ] || [ -z $productId ]; then
        return 1
    fi

    vendorId=`echo $vendorId | sed 's/0x//g'`
    productId=`echo $productId | sed 's/0x//g'`

    lsusb | grep "$vendorId:$productId" > /dev/null
    [ $? -eq 0 ] && return 0

    return 2
}

#
# Check process is parent
#
# param[in] $1: none
#
# return  Is parent, zero is returned.
#         Not parent, others is returned.
#
Common_iIsParent()
{
    local process=`ps -p $PPID | awk '{print $4}'| tail -1`
    #echo "process: $process"

    if [ "$process" = "sudo" ]; then
        return 0
    fi

    return 1
}

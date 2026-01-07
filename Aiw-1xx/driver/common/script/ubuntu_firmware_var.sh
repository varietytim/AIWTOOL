#!/bin/sh

#
# The system folders to find the firmware in Ubuntu
#
gFirmwarePath=/lib/firmware
gFwLogFile=/tmp/dmesg.driver.log



#
# To setup firmware
#
# param[in] $1: the path to find the firmware.
# param[in] $2: the name of firmware that will be copy to system path.
# param[in] $3: the path to decompress the tarball.
# param[in] $4: the filter pattern with firmware version.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
WiFiFW_iSetup()
{
    if [ -z $1 ] || [ -z $2 ] || [ -z $3 ] || [ -z $4 ]; then
        Msg "Arguments is null"
        return 1
    fi

    local fw_source_path=$1
    local fw_name=$2
    local fw_untar_path=$3
    local fw_filter_pattern=$4
    
    #
    # Check firmware exist or not
    #
    if [ ! -e "$fw_source_path" ]; then
        if [ -e $fw_source_path.tar.bz2 ]; then
            tar jxvf $fw_source_path.tar.bz2 -C "$fw_untar_path"
        elif [ -e $fw_source_path.tgz ]; then
            tar zxvf $fw_source_path.tgz -C "$fw_untar_path"
        else
            ExitIfError 100 "Not find the tarball!"
        fi
        #tar jxvf $fw_source_path.tar.bz2 -C "$fw_untar_path"
        ExitIfError $? "the tarball to decompress is failed !"
    fi
    
    #
    # Check system folder exist or not
    #
    if [ ! -e $gFirmwarePath ]; then
        ExitIfError 101 "the firmware path is not exist!"
    fi

    #
    # Check the old firmware exist in system or not.
    # if it is exist, rename it as .orig as suffix.
    #
    local firmware_ready=0
    local filename;
    for file in $(ls /lib/firmware/${fw_filter_pattern}*);
    #for file in $(ls ./test/iwlwifi-ty-a0-gf-a0*);
    do
        filename=$(basename $file)
        #echo "file name: $filename"

        #if [ "$filename" = "iwlwifi-ty-a0-gf-a0-59.ucode" ]; then
        if [ "$filename" = "$fw_name" ]; then
            Msg "firmware($filename) is ready"
            firmware_ready=1
        else
            if [ $(echo $filename | grep 'ucode$\|pnvm$') ]; then
                #echo "bingo: $filename"
                Msg "Rename file $file to $file.orig"
                mv -i "$file" "$file.orig"
            fi
        fi
    done

    # Copy firmware to system.            
    if [ $firmware_ready -eq 0 ]; then
        Msg "Copy driver($fw_name) to $gFirmwarePath"
        cp $fw_source_path/$fw_name $gFirmwarePath
        ExitIfError $? "copy firmware failed !"
    fi

    # Reload the driver
    modprobe -r iwlwifi
    modprobe iwlwifi

    return 0
}

#
# To clean driver in the system
#
# param[in] $1: the path to find the source of driver.
# param[in] $2: the name of driver that will copy to system path.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
WiFiFW_iClean()
{
    if [ -z $1 ] || [ -z $2 ]; then
        Msg "Arguments is null"
        return 1
    fi

    local fw_source_path=$1
    local fw_name=$2

    # Check the firmware exist
    if [ -e "$gFirmwarePath/$fw_name" ]; then
        Msg "Remove firmware ($gFirmwarePath/$fw_name)"
        rm -i "$gFirmwarePath/$fw_name"
    fi
    
    # Remove source
    if [ -e "$fw_source_path" ]; then
        Msg "$fw_source_path"
        rm -rI $fw_source_path
    fi

    return 0
}

#
# Check firmware is ready in the system
#
# param[in]: none.
#
# return  Ready, zero is returned.
#         Not ready, others is returned.
#
WiFiFW_iIsFwReady()
{
    local ret;
    local start;
    local end

    dmesg | grep iwlwifi > $gFwLogFile
    ret=`grep -n "loaded firmware version\|Direct firmware load for" $gFwLogFile | tail -n 1 | cut -d: -f1`
    if [ -z $ret ]; then
        Dbg "not found the firmware version"
        return 1
    fi

    start=$ret
    end=$((start+20))
    sed -n "${start},${end}p" $gFwLogFile | grep -w "base HW address" > /dev/null
    if [ $? -ne 0 ]; then
        Dbg "The firmware is not ready, not found the MAC address."
        return 2
    fi

    Dbg "The firmware is ready."
    return 0
}

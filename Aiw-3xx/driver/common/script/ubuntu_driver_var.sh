#!/bin/sh

#
# The system folders to find the driver in Ubuntu
#
gDriverPath=/lib/modules/`uname -r`/kernel/drivers/net/usb
gDriverBlacklistFile=/etc/modprobe.d/blacklist.conf

#
# To setup driver
#
# param[in] $1: the path to find the source of driver.
# param[in] $2: the name of driver that will copy to system path.
# param[in] $3: the path to decompress the tarball.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Driver_iSetup()
{
    if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
        Msg "Arguments is null"
        return 1
    fi

    local drv_source_path=$1
    local drv_name=$2
    local drv_untar_path=$3

    # Check driver exist
    if [ ! -e "$drv_source_path" ]; then
        tar jxvf $drv_source_path.tar.bz2 -C "$drv_untar_path"
        ExitIfError $? "the driver is not exist !"
    fi

    # Build driver
    Msg "Build driver......"
    make -C $drv_source_path clean
    make -C $drv_source_path
    ExitIfError $? "Build driver failed !"

    # Copy driver
    if [ ! -e $gDriverPath ]; then
        ExitIfError 100 "the driver path is not exist!"
    fi

    Msg "Copy driver($drv_name) to $gDriverPath"
    cp $drv_source_path/$drv_name $gDriverPath
    ExitIfError $? "copy driver failed !"
    depmod -a

    # Check qmi_wwan driver exist
    #if [ -e $gDriverPath/qmi_wwan.ko ]; then
        # /etc/modprobe.d/blacklist.conf
        # blacklist qmi_wwan.ko
    #    Msg "The driver qmi_wwan.ko is exist."

    #    local ret=`cat $gDriverBlacklistFile | grep "qmi_wwan$"`
    #    if [ -z $ret ]; then
    #        if [ ! -e $gDriverBlacklistFile.orig ]; then
    #            cp $gDriverBlacklistFile $gDriverBlacklistFile.orig
    #        fi
    #        sh -c "echo blacklist qmi_wwan >> $gDriverBlacklistFile"
    #        ExitIfError $? "Add qmi_wwan to blacklist failed!"
    #        Msg "Add qmi_wwan to blacklist."
    #    fi
    #fi

    # Unmark the qmi_wwan driver in the blacklist
    #grep "^#blacklist.*qmi_wwan$" $gDriverBlacklistFile > /dev/null 2>&1
    #if [ $? -eq 0 ]; then
    #    sed -i 's/^#blacklist.*qmi_wwan$/blacklist qmi_wwan/' $gDriverBlacklistFile
    #    ExitIfError $? "Unmark qmi_wwan in the blacklist failed!"
    #    Msg "Unmark qmi_wwan."
    #fi
    
    return 0
}

#
# To clean driver in system
#
# param[in] $1: the path to find the source of driver.
# param[in] $2: the name of driver that will copy to system path.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Driver_iClean()
{
    if [ -z $1 ] || [ -z $2 ]; then
        Msg "Arguments is null"
        return 1
    fi

    local drv_source_path=$1
    local drv_name=$2
    local tmp;

    # Unload the driver
    tmp=$(lsmod | grep -w "^${drv_name%\.ko}")
    if [ ! -z "$tmp" ]; then
        Msg "Unload the driver ${tmp%% *}"
        modprobe -r ${tmp%% *}
    fi

    # Check the driver exist
    if [ -e "$gDriverPath/$drv_name" ]; then
        rm -i "$gDriverPath/$drv_name"
        depmod -a
    fi
    
    # Remove source
    if [ -e "$drv_source_path" ]; then
        Msg "$drv_source_path"
        rm -rI $drv_source_path
    fi

    # Mark the qmi_wwan in the blacklist
    #grep "^blacklist.*qmi_wwan$" $gDriverBlacklistFile > /dev/null 2>&1
    #if [ $? -eq 0 ]; then
    #    sed -i 's/^blacklist.*qmi_wwan$/#blacklist qmi_wwan/' $gDriverBlacklistFile
    #    ExitIfError $? "Mark qmi_wwan in the blacklist failed!"
    #    Msg "Mark qmi_wwan."
    #fi

    return 0
}

#
# Add qmi_wwan driver into blacklist
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Driver_iDisableQmi()
{
    # Check qmi_wwan driver exist
    if [ -e $gDriverPath/qmi_wwan.ko ]; then
        # /etc/modprobe.d/blacklist.conf
        # blacklist qmi_wwan.ko
        Msg "The driver qmi_wwan.ko is exist."

        local ret=`cat $gDriverBlacklistFile | grep "qmi_wwan$"`
        if [ -z $ret ]; then
            if [ ! -e $gDriverBlacklistFile.orig ]; then
                cp $gDriverBlacklistFile $gDriverBlacklistFile.orig
            fi
            sh -c "echo blacklist qmi_wwan >> $gDriverBlacklistFile"
            ExitIfError $? "Add qmi_wwan to blacklist failed!"
            Msg "Add qmi_wwan to blacklist."
        fi
    fi

    # Unmark the qmi_wwan driver in the blacklist
    grep "^#blacklist.*qmi_wwan$" $gDriverBlacklistFile > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        sed -i 's/^#blacklist.*qmi_wwan$/blacklist qmi_wwan/' $gDriverBlacklistFile
        ExitIfError $? "Unmark qmi_wwan in the blacklist failed!"
        Msg "Unmark qmi_wwan."
    fi

    return 0
}

#
# Remove qmi_wwan driver from blacklist
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Driver_iEnableQmi()
{
    # Mark the qmi_wwan in the blacklist
    grep "^blacklist.*qmi_wwan$" $gDriverBlacklistFile > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        sed -i 's/^blacklist.*qmi_wwan$/#blacklist qmi_wwan/' $gDriverBlacklistFile
        ExitIfError $? "Mark qmi_wwan in the blacklist failed!"
        Msg "Mark qmi_wwan."
    fi

    return 0
}

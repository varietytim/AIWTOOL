#!/bin/sh

#
# Check the driver is ready or not
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
MbimDrv_IsDriverReady()
{
    local drive_name=`lsusb -t | grep "Driver=cdc_mbim" | grep "Class=Communications" | awk -F, '{ printf $4 }' | cut -d '=' -f 2`
    if [ "$drive_name" = "cdc_mbim" ]; then
        Dbg "Mbim is ready"
        return 0
    else
        Dbg "Not find MBIM driver"
        return 1
    fi
}

#
# Load the driver with MBIM
#
# param[in] $1: the interval of delay time to retry.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
MbimDrv_LoadDriver()
{
    local ret;
    local end;
    local drv_ready;
    local delay=$1

    [ -z $delay ] && delay=0.5
    Dbg "the interval of delay time is $delay second"

    end=10
    for i in $(seq 1 $end)
    do
        modprobe cdc_mbim
        #ExitIfError $? "modprobe cdc_mbim failed"
        [ $? -ne 0 ] && Dbg "modprobe cdc_mbim failed" && return $?
        Dbg "modprobe cdc_mbim"
        sleep 0.1

        MbimDrv_IsDriverReady
        if [ $? -eq 0 ]; then
            drv_ready=0
            Dbg "[$i] Load cdc_mbim successful"
            sleep 0.5
            break
        else
            modprobe -r cdc_mbim
            Dbg "modprobe -r cdc_mbim"
        fi

        drv_ready=1
        Dbg "[$i] try to load cdc_mbim"
        sleep $delay
    done

    return $drv_ready
}

#
# Unload the driver with MBIM
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
MbimDrv_UnloadDriver()
{
    local ret;

    lsmod | grep -w 'cdc_mbim' > /dev/null
    if [ $? -eq 0 ]; then
        modprobe -r cdc_mbim
        ret=$?
        Dbg "modprobe -r cdc_mbim (ret:$ret)"
    else
        Dbg "the cdc_mbim is not loaded"
        ret=0
    fi

    return $ret
}

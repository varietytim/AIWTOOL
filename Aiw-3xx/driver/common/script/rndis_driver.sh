#!/bin/sh

#
# Check the driver is ready or not
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
RndisDrv_IsDriverReady()
{
    local drive_name=`lsusb -t | grep -w "Driver=rndis_host" | grep "Class=CDC Data" | awk -F, '{ printf $4 }' | cut -d '=' -f 2`

    if [ "$drive_name" = "rndis_host" ]; then
        Dbg "RNDIS driver is ready"
        return 0
    else
        Dbg "Not find RNDIS driver"
        return 1
    fi
}

#
# Load the driver with RNDIS
#
# param[in] $1: the interval of delay time to retry.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
RndisDrv_LoadDriver()
{
    local ret;
    local end;
    local drv_ready;
    local delay=$1

    [ -z $delay ] && delay=0.5
    Dbg "the interval of delay time is $delay second"

    end=10

    modprobe -r rndis_host

    for i in $(seq 1 $end)
    do
        modprobe rndis_host rndis_wlan
        [ $? -ne 0 ] && Dbg "modprobe rndis_host failed" && return $?
        Dbg "modprobe rndis_host"
        sleep 0.1

        RndisDrv_IsDriverReady
        if [ $? -eq 0 ]; then
            drv_ready=0
            Dbg "[$i] Load rndis_host successful"
            sleep 0.5
            break
        else
            modprobe -r rndis_wlan rndis_host
            Dbg "modprobe -r rndis_wlan rndis_host"
        fi

        drv_ready=1
        Dbg "[$i] try to load rndis_host"
        sleep $delay
    done

    return $drv_ready
}

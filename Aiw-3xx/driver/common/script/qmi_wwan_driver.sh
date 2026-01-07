#!/bin/sh

#
# Check the driver is ready or not
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
QmiDrv_IsDriverReady()
{
    local drive_name=`lsusb -t | grep "Driver=qmi_wwan" | awk -F, '{ printf $4 }' | cut -d '=' -f 2`
    if [ "$drive_name" = "qmi_wwan" ]; then
        Dbg "QMI WWAN driver is ready"
        return 0
    else
        Dbg "Not find QMI WWAN driver"
        return 1
    fi
}

#
# Load the driver
#
# param[in] $1: the interval of delay time to retry.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
QmiDrv_LoadDriver()
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
        modprobe qmi_wwan
        [ $? -ne 0 ] && Dbg "modprobe qmi_wwan driver failed" && return $?
        Dbg "modprobe qmi_wwan"
        sleep 0.1

        QmiDrv_IsDriverReady
        if [ $? -eq 0 ]; then
            drv_ready=0
            Dbg "[$i] Load qmi_wwan successful"
            sleep 0.5
            break
        else
            modprobe -r qmi_wwan
            Dbg "modprobe -r qmi_wwan"
        fi

        drv_ready=1
        Dbg "[$i] try to load qmi_wwan"
        sleep $delay
    done

    return $drv_ready
}

#
# Unload the driver
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
QmiDrv_UnloadDriver()
{
    local ret;
    
    lsmod | grep -w 'qmi_wwan' > /dev/null
    if [ $? -eq 0 ]; then
        modprobe -r qmi_wwan
        ret=$?
        Dbg "modprobe -r qmi_wwan (ret:$ret)"
    else
        Dbg "the qmi_wwan is not loaded"
        ret=0
    fi

    return $ret
}


#!/bin/sh

#
# Load option driver
#
# param[in] $1: vendor ID.
# param[in] $2: product ID.
# param[in] $3: append to .
#
# return  On success, zero is returned.
#         On error, others is returned.
#
OptionDrv_Load()
{
    local vendorId=$1
    local productId=$2
    local append='>'

    modprobe option
    Dbg "modprobe option"
    sleep 0.1
        
    [ "$3" = "append" ] && append='>>'

    if [ ! -z $vendorId ] && [ ! -z $productId ]; then
        sh -c "echo $vendorId $productId $append /sys/bus/usb-serial/drivers/option1/new_id"
        Dbg "Write the vendor ID:$vendorId & product ID:$productId."
    else
        Dbg "the argument of vendor ID or product ID is null!"
        return 1
    fi

    return 0
}

#
# Unload option driver
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
OptionDrv_UnLoad()
{
    local ret;
    
    modprobe -r option
    ret=$?
    Dbg "modprobe -r option"

    return $ret
}

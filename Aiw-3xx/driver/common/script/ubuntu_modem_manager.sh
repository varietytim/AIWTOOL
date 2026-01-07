#!/bin/sh

#
# Check modem manager enable or not
#
# param[in]: none.
#
# return  Enable, zero is returned.
#         Disable, others is returned.
#
ModemMgr_iIsEnable()
{
    local ret=`systemctl is-enabled ModemManager`
    if [ "$ret" != "disabled" ]; then
        return 0
    fi

    return 1
}

#
# Copy configuration to system
#
# param[in]: none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
ModemMgr_iDisable()
{
    systemctl disable ModemManager
    ExitIfError $? "Disable ModemManager failed!"

    return 0
}


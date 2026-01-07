#!/bin/sh

#
# The folder to find the template with service
#
gSDir_Service="$gTopdir/driver/common/system/systemd/aiw-wifi-roam"

#
# The system folders in Ubuntu
#
gSystemdEtcPath=/etc/systemd/system
gSystemdLibPath=/lib/systemd/system
gEtcPath=/etc
gServiceName=aiw-wifi-roam.service

#
# The path of boot running script that is written by setup.sh.
# Dependence on setup_var.sh
#
gRServiceBootFile="$gUsrCfgdir/aiw-rc.local"

#
# Write the file of rc.local
#
# param[in] $1: delay time in second while booting.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Service_iWriteScript()
{
    local second=$1

    [ -z $second ] && return 1

    echo '#!/bin/sh' > $gRServiceBootFile
    echo 'echo "Start to connect with WiFi ..." > /tmp/aiw-wifi.log' >> $gRServiceBootFile
    local tmp="$gTopdir/tool/monitor.sh \"connect=$second\" &"
    echo "$tmp" >> $gRServiceBootFile
    echo 'exit 0' >> $gRServiceBootFile
    sync;sync;sync
    chmod 777 $gRServiceBootFile

    return 0
}

#
# Copy configuration to system
#
# param[in]: none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Service_iCopyToSystem()
{
    cp -ap "$gSDir_Service/$gServiceName" $gSystemdLibPath
    ExitIfError $? "Copy $gServiceName failed!"
    Msg "Copy $gServiceName to $gSystemdLibPath."

    #WriteRCScript
    cp -ap $gRServiceBootFile $gEtcPath
    ExitIfError $? "Copy $gRServiceBootFile failed!"
    Msg "Copy $gRServiceBootFile to $gEtcPath."

    return 0
}

#
# Check service enable or not
#
# param[in]: none.
#
# return  Enable, zero is returned.
#         Disable, others is returned.
#
Service_iIsEnable()
{
    if [ ! -e "$gSystemdEtcPath/$gServiceName" ]; then
        return 1
    fi

    return 0
}

#
# Enable service
#
# param[in]: none.
#
# On success, zero is returned.
# On error, others is returned.
#

Service_iEnable()
{
    #+systemctl enable rc-local 2> /dev/null
    systemctl enable $gServiceName 2> /dev/null
    ExitIfError $? "Enable $gServiceName failed!"

    return 0
}

#
# Romove all service file
#
# param[in]: none.
#
# On success, zero is returned.
# On error, others is returned.
#

Service_iClean()
{
    echo '#!/bin/sh' > $gRServiceBootFile
    echo 'exit 0' >> $gRServiceBootFile
    chmod 777 $gRServiceBootFile

    mv $gRServiceBootFile $gEtcPath
    ExitIfError $? "Copy $gRServiceBootFile failed!"
 
    sync;sync;sync

    return 0
}

#
# Restart service
#
# param[in]: none.
#
# On success, zero is returned.
# On error, others is returned.
#
Service_iRestart()
{
    systemctl restart $gServiceName 2> /dev/null
    ExitIfError $? "Restart $gServiceName failed!"

    return 0
}

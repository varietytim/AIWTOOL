#!/bin/sh

#
# The folder to find the template with rc-local
#
gSDir_RcLocal="$gTopdir/driver/common/system/systemd/rc-local"

#
# The system folders in Ubuntu
#
gRcLocalServiceEtcPath=/etc/systemd/system
gRcLocalServicePath=/lib/systemd/system
gRcLocalPath=/etc
gRcLocalServiceName=rc-local.service

#
# The path of rc.local that is written by setup.sh.
# Dependence on setup_var.sh
#
#gRcLocalName=rc.local
#[change] gRcLocalFile="$gRcLocalSrcdir/rc.local"
#gRcLocalFile="$gWDir_RcLocal/rc.local"
gRcLocalFile="$gUsrCfgdir/rc.local"

#
# Write the file of rc.local
#
# param[in] $1: delay time in second while booting.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
RcLocal_iWriteScript()
{
    local second=$1

    [ -z $second ] && return 1

    echo '#!/bin/sh' > $gRcLocalFile
    echo 'echo "Start to dial out ..." > /tmp/rc-local.log' >> $gRcLocalFile
    local tmp="$gTopdir/tool/monitor.sh \"dialout=$second\" &"
    echo "$tmp" >> $gRcLocalFile
    echo 'exit 0' >> $gRcLocalFile
    sync;sync;sync
    chmod 777 $gRcLocalFile

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
RcLocal_iCopyToSystem()
{
    cp -ap "$gSDir_RcLocal/$gRcLocalServiceName" $gRcLocalServicePath
    ExitIfError $? "Copy $gRcLocalServiceName failed!"
    Msg "Copy $gRcLocalServiceName to $gRcLocalServicePath."

    #WriteRCScript
    cp -ap $gRcLocalFile $gRcLocalPath
    ExitIfError $? "Copy $gRcLocalFile failed!"
    Msg "Copy $gRcLocalFile to $gRcLocalPath."

    return 0
}

#
# Check rc-local enable or not
#
# param[in]: none.
#
# return  Enable, zero is returned.
#         Disable, others is returned.
#
RcLocal_iIsEnable()
{
    if [ ! -e "$gRcLocalServiceEtcPath/$gRcLocalServiceName" ]; then
        return 1
    fi

    return 0
}

#
# Enable rc-local
#
# param[in]: none.
#
# On success, zero is returned.
# On error, others is returned.
#

RcLocal_iEnable()
{
    systemctl enable rc-local 2> /dev/null
    ExitIfError $? "Enable rc-local service failed!"

    return 0
}

#
# Romove all rc-local file
#
# param[in]: none.
#
# On success, zero is returned.
# On error, others is returned.
#

RcLocal_iClean()
{
    echo '#!/bin/sh' > $gRcLocalFile
    echo 'exit 0' >> $gRcLocalFile
    chmod 777 $gRcLocalFile

    mv $gRcLocalFile $gRcLocalPath
    ExitIfError $? "Copy $gRcLocalFile failed!"
 
    sync;sync;sync

    return 0
}

#
# Restart rc-local
#
# param[in]: none.
#
# On success, zero is returned.
# On error, others is returned.
#
RcLocal_iRestart()
{
    systemctl restart rc-local 2> /dev/null
    ExitIfError $? "Restart rc-local service failed!"

    return 0
}

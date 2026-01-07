#!/bin/sh

#
# For QMI WWAN to dial out
# Dependence on setup_var.sh
#
gSystemCfgPath=/etc
gQmiCfgFile="$gUsrCfgdir/qmi-network.conf"


#
# Write configuration with QMI WWAN
#
# param[in] $1: the string of APN.
# param[in] $2: the string of username.
# param[in] $3: the string of password.
# param[in] $4: the string of authentication.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
QmiCfg_iWriteCfg()
{
    local apn="$1"
    local username="$2"
    local password="$3"
    local auth="$4"
    local tmp;
    
    [ -z $apn ] && return 1

    #
    # For APN
    #
    tmp='APN=internet'
    tmp=`echo "$tmp" | sed -e "s/internet/$apn/g"`
    echo "$tmp" > $gQmiCfgFile
    
    #
    # For authentication
    # Currently not found the APN_AUTH defined in qmi-network.conf
    #
    #if [ ! -z $username  ] && [ ! -z $password ] &&  [ ! -z $auth ]; then
    if [ ! -z $username  ] && [ ! -z $password ] ; then
        echo "APN_USER=$username" >> $gQmiCfgFile
        echo "APN_PASS=$password" >> $gQmiCfgFile
        #echo "APN_AUTH=$auth" >> $gQmiCfgFile
    fi
    
    #
    # Default option
    echo 'PROXY=no' >> $gQmiCfgFile
    
    sync;sync;sync
    chmod 755 $gQmiCfgFile

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
QmiCfg_iCopyToSystem()
{
    cp -ap $gQmiCfgFile $gSystemCfgPath
    ExitIfError $? "Copy $gQmiCfgFile failed!"
    Msg "Copy $gQmiCfgFile to $gSystemCfgPath."

    return 0
}

#
# To clean QMI WWAN configuration in system
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
QmiCfg_iClean()
{
    #
    # Remove QMI WWAN configuration
    #
    if [ -e "$gSystemCfgPath/qmi-network.conf" ]; then
        rm -i "$gSystemCfgPath/qmi-network.conf"
    fi

    return 0
}


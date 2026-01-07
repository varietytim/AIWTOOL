#!/bin/sh

#
# For MIBM to dial out
# Dependence on setup_var.sh
#
gSDir_MbimScript="$gTopdir/driver/common/app/mbim-set-ip"
gMbimCfgPath=/etc
gMbimCfgName="$gUsrCfgdir/mbim-network.conf"
gMbimApn=internet


#
# Write configuration with MBIM
#
# param[in] $1: the string of APN.
# param[in] $2: the string of username.
# param[in] $3: the string of password.
# param[in] $4: the string of authentication.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
MbimCfg_iWriteCfg()
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
    echo "$tmp" > $gMbimCfgName
    
    #
    # For authentication
    #
    if [ ! -z $username  ] && [ ! -z $password ] &&  [ ! -z $auth ]; then
        echo "APN_USER=$username" >> $gMbimCfgName
        echo "APN_PASS=$password" >> $gMbimCfgName
        echo "APN_AUTH=$auth" >> $gMbimCfgName
    fi
    
    #
    # Default option
    #   
    echo 'PROXY=yes' >> $gMbimCfgName
    
    sync;sync;sync
    chmod 755 $gMbimCfgName

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
MbimCfg_iCopyToSystem()
{
    cp -ap $gMbimCfgName $gMbimCfgPath
    ExitIfError $? "Copy $gMbimCfgName failed!"
    Msg "Copy $gMbimCfgName to $gMbimCfgPath."

    return 0
}

#
# To clean MBIM configuration in system
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
MbimCfg_iClean()
{
    #
    # Remove MBIM configuration
    #
    if [ -e "$gMbimCfgPath/mbim-network.conf" ]; then
        rm -i "$gMbimCfgPath/mbim-network.conf"
    fi

    return 0
}

#
# Check the state of registration with MBIM
#
# param[in] $1: the path to find the device node.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
MbimCli_iCheckReg()
{
    local devnode="$1"
    local ret;

    [ -z "$devnode" ] && return 1 

    ret=`mbimcli -p --query-registration-state --device="$devnode" | grep "Register state" | cut -d: -f2 | sed "s/ //g" | sed "s/'//g"`

    if [ "$ret" = "home" ]; then
        return 0
    fi

    return 2
}

#
# Get IP address
#
# param[in] $1: the path to find the device node.
# param[out] gRetStr: IP address
#
# return  On success, zero is returned.
#         On error, others is returned.
#
MbimCli_iGetIp()
{
    local devnode="$1"
    local ip_addr;

    [ -z "$devnode" ] && return 1

    ip_addr=`mbimcli -d $devnode -p --query-ip-configuration | grep -w "IP" | cut -d"'" -f2 | grep -w "[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*" | cut -d'/' -f1`
    ret=$?
    if [ $ret -eq 0 ]; then
        if [ ! -z "$ip_addr" ]; then
            gRetStr=$ip_addr
            return 0
        else 
            return 2
        fi
    else
        return $ret
    fi
}

#============================================================================
# Connect script
#============================================================================
#!/bin/sh

#
# The folders 
#
gWorkdir=$(dirname $(readlink -f $0))
gTopdir="$(dirname $(dirname $(dirname $gWorkdir)))"
gCommonDir=${gTopdir}/tool/common
gDriverCommonDir=${gTopdir}/driver/common

#
# Golobal variables
#
. $gCommonDir/common_var.sh
. $gDriverCommonDir/script/wpa_supplicant_cfg.sh
. $gDriverCommonDir/script/ubuntu_wpa_supplicant.sh

#
# Import modules
#
. $gCommonDir/common.sh
. $gCommonDir/debug.sh
. $gCommonDir/log.sh
. $gCommonDir/parser.sh
. $gCommonDir/connect_err.sh
. $gCommonDir/argument.sh

#
# Misc
#
gStartFlag=1
gDelayTime=0
gNetIfaceFlag=0


#====================================
#============ Functions =============
#====================================
Start()
{
    local iface;
    local cur_ssid;
    local ssid_not_match=0
    local ret;

    #
    # Check WiFi network interface
    #
    Dbg "default wifi interface is $DEF_WIFI_IF"
    Common_iFindNetInterface "$DEF_WIFI_IF"
    if [ $? -ne 0 ]; then
        return $CErr_NOINF
    else
        iface=$gRetStr
        Dbg "Find the WiFi interface is $iface"
    fi
   
    #
    # Init or get current SSID
    #
    WpaS_iGetCurSsid
    if [ $? -eq 0 ]; then
        cur_ssid="$gRetStr"
        Dbg "Current SSID is $gRetStr"
    else
        if WpaS_iRecordSsid "$gCfgSsid"; then
            Dbg "Init to record SSID."
            cur_ssid="$gCfgSsid"
        else
            return $CErr_RECORDSSID
        fi
    fi

    #    
    # Run the connection service
    #
    if WpaS_iRunSupplicant "$gWpasCfgFile"; then
        Dbg "Start to run wpa_supplicant successful"
    else
        return $CErr_SUPPLICANT
    fi

    #
    # Check SSID and IP address
    #
    if [ "$cur_ssid" != "$gCfgSsid" ]; then
        ssid_not_match=1
        Dbg "Current SSID($cur_ssid) isn't match with cfg SSID($gCfgSsid)."
        
        Dbg "Release IP by dhcp client"
        #dhclient -v -r $iface
        dhclient -r $iface > /dev/null 2>&1
        if WpaS_iRecordSsid "$gCfgSsid"; then
            Dbg "Update record SSID ($gCfgSsid)."
        else
            Dbg "Update record SSID ($gCfgSsid) failed."
            return $CErr_RECORDSSID
        fi
    fi

    if ! Common_iGetNetIp $iface; then
        Dbg "run the dhcp client to get IP"
        #dhclient -v
        dhclient > /dev/null 2>&1
    fi

    #
    # Setting by roaming
    #
    if [ $gCfgRoamEnable -eq 1 ]; then
        Msg "Setting with roaming..."
        
        WpaS_iSetRoam "$iface" $gCfgRssiThreshold $gCfgScanShortInterval $gCfgScanLongInterval
        ret=$?
        if [ $ret -ne 0 ]; then
            [ $ret -eq 1 ] && return $CErr_NULL
            [ $ret -eq 2 ] && return $CErr_SETROAM
            [ $ret -eq 3 ] && return $CErr_REASSOCIATE
        fi
    fi

    Msg "Connection service is running." 
    return 0
}

Stop()
{
    if WpaS_iStopSupplicant; then
        Dbg "To stop wpa_supplicant successful."
        return 0
    else
        Dbg "To stop wpa_supplicant failed"
        return $CErr_STOPSUPPLICANT
    fi

    Dbg "Not found the connection service." 
    return 0
}

GetUserInfo()
{
    if [ ! -z $gCfgSsid ]; then
        Msg "SSID is '$gCfgSsid'"
    else
        gCfgSsid='advantech'
        Msg "Default SSID is '$gCfgSsid'"
    fi

    #if [ ! -z $gCfgPassword ]; then
    #    Msg "Password is '$gCfgPassword'"
    #fi
    
    if [ ! -z $gCfgRoamEnable ]; then
        Msg "Roam enable/disable is '$gCfgRoamEnable'"
    fi
    
    if [ ! -z $gCfgRssiThreshold ]; then
        Msg "RSSI threshold is '$gCfgRssiThreshold'"
    fi
    
    if [ ! -z $gCfgRssiHysterisis ]; then
        Msg "RSSI Hysterisis is '$gCfgRssiHysterisis'"
    fi
    
    if [ ! -z $gCfgScanLongInterval ]; then
        Msg "Scan long interval is '$gCfgScanLongInterval'"
    fi
    
    if [ ! -z $gCfgScanShortInterval ]; then
        Msg "Scan short interval is '$gCfgScanShortInterval'"
    fi
}

#
# Show the version
#
if [ -e $gVersionFile ]; then
    . $gVersionFile
else
    gVersion="Unknow"
fi
echo "==============================================="
Msg "\t\t$gVersion"
echo "==============================================="

#
# Check permission
#
Common_iIsRoot
gRet=$?
[ $gRet -ne 0 ] && Echo "Please use 'sudo' to run $0." && exit 1

#
# Detect HW module
#
Common_iCheckModuleID $gCfgVendorId $gCfgProductId
if [ $? -ne 0 ]; then
    Common_iCheckModuleID $gCfgVendorId2 $gCfgProductId2
    [ $? -ne 0 ] && Msg "Not detect the hardware '$gCfgModelName'" && exit 1
fi

#
# Init error code & log
#
CErr_Init
Log_Init

#
# check model name
#
[ -z $gCfgModelName ] && Msg "Not find model name in configuration!" && exit 1
gModuleName=$gCfgModelName
Msg "Model: $gModuleName"

if [ "$gCfgModelName" != "${gWorkdir##*/}" ]; then
    Msg "The model name(${gWorkdir##*/}) isn't match with $gCfgModelName"
    Msg "Please go to setup again!"
    exit 0
fi

#
# To parser arguments
#
for arg in $@
do
    #echo "arg: $arg"
    if [ $gDebug -le 0 ]; then
        Dbg_iParserLevel "$arg"
        gRet=$?
        [ $gRet -ne 0 ] && gDebug=$gRet && Msg "Debug level: $gDebug"
    fi

    [ $gDelayTime -le 0 ] && Arg_KvDelayTime $arg 'gDelayTime'
    [ $gStartFlag -eq 1 ]  && Arg_Stop $arg 'gStartFlag' '0' 
    #-[ $gNetIfaceFlag -eq 0 ] && Arg_NetIface $arg 'gNetIfaceFlag' '1'
done

#
# Wait for system init
#
[ $gDelayTime -ge 1 ] && Msg "Delay $gDelayTime seconds for system init" && sleep $gDelayTime

#
# Get user config
#
GetUserInfo

#
# Enable log or not
#
Log_GetLogLevel
gRet=$? && [ $gRet -ge $L_LEVEL2 ]
Log_AddString "\n<< Start to connect... >>\n"

#
# To connect/disconnect to AP router
# by action start or stop
#
if [ $gStartFlag -ne 0 ]; then
    Msg "Start to connect..."
    Start
    gRet=$?
else
    Msg "Stop service and disconnected."
    Stop
    gRet=$?
fi

if [ $gRet -ne 0 ]; then
    ExitIfError $gRet "($gRet) $(CErr_strCode2Msg $gRet)"
fi

Msg "Complete."
exit 0


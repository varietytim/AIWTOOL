#============================================================================
# Monitor script 
#============================================================================
#!/bin/sh

#
# Work folders
#
gWorkdir=$(dirname $(readlink -f $0))
gTopdir=$(dirname $gWorkdir)
gCommonDir=${gWorkdir}/common
gDriverCommonDir=${gTopdir}/driver/common

#
# Golobal variables
#
. $gCommonDir/common_var.sh

#
# Import modules
#
. $gCommonDir/common.sh
. $gCommonDir/debug.sh
. $gCommonDir/key_var.sh
. $gCommonDir/log.sh
. $gCommonDir/parser.sh
. $gCommonDir/monitor_ctrl.sh

#
# Error code
#
R_IP_NOIFACE=1
R_IP_GETSTATFAIL=2
R_IP_GETSNRFAIL=3
R_IP_PARSERFAIL=4

#
# Other scripts
#
gToolCmd="$gWorkdir/tool.sh"
gConnectScript=${gTopdir}/driver/connect.sh

#
# Misc
#
gConnectDebug=0
gDelayTime=0
gConnectOnce=0
#-gRegRetryArgs="regcnt=1"
gUpdateFailCnt=0
#-gResetFlag=0


#====================================
#============ Functions =============
#====================================
RunTool()
{
    gRunCmd=$1 
    $gToolCmd $@ > /dev/null

    return $?
}

MsgAndLog()
{
    Msg "$1"
    Log_AddString "$1"
}

ChkNLog_UpdateInfo()
{
    local rssi;
    local bssid;
    local ssid;
    local snr;
    local iface;

    Common_iFindNetInterface "$DEF_WIFI_IF"
    if [ $? -eq 0 ]; then
        iface="$gRetStr"
        Dbg "The network interface is $iface"
    else
        MsgAndLog "Not found the network interface ($DEF_WIFI_IF)."
        return $R_IP_NOIFACE
    fi
    
    RunTool GetStatus $iface 
    if [ $? -eq 0 ]; then
        ssid=$(Log_GetVaule "$KEY_SSID")
        [ -z $ssid ] && Msg "Get value with $KEY_SSID is null!" && return $R_IP_PARSERFAIL
        Dbg "ChkNLog_UpdateInfo SSID: $ssid"
        Log_AddString "[SSID]: $ssid"
        
        bssid=$(Log_GetVaule "$KEY_BSSID")
        [ -z $bssid ] && Msg "Get value with $KEY_BSSID is null!" && return $R_IP_PARSERFAIL
        Dbg "ChkNLog_UpdateInfo BSSID: $bssid"
        Log_AddString "[BSSID]: $bssid"
        
        rssi=$(Log_GetVaule "$KEY_RSSI")
        [ -z $rssi ] && Msg "Get value with $KEY_RSSI is null!" && return $R_IP_PARSERFAIL
        Dbg "ChkNLog_UpdateInfo RSSI: $rssi"
        Log_AddString "[RSSI]: $rssi"
    else
        MsgAndLog "Get status failed."
        return $R_IP_GETSTATFAIL
    fi
    
    if [ ! -z $bssid ]; then
        RunTool GetSnr $iface $bssid
        if [ $? -eq 0 ]; then
            snr=$(Log_GetVaule "$KEY_SNR")
            [ -z $snr ] && Msg "Get value with $KEY_SNR is null!" && return $R_IP_PARSERFAIL
            Dbg "ChkNLog_UpdateInfo SNR: $snr"
            Log_AddString "[SNR]: $snr"
        else
            MsgAndLog "Get SNR failed."
            return $R_IP_GETSNRFAIL
        fi
    fi

    return 0
}

CheckDebugFlag()
{
    local tmp=`echo "$1" | grep debug | cut -d'=' -f2`
    if [ ! -z $tmp ] && [ $tmp -ge 1 ] 2> /dev/null; then
        gDebug=$tmp
        Msg "Debug level: $gDebug"
    else
        gDebug=0
    fi

    return 0
}

CheckConnectFlag()
{
    Monitor_IsBootDialForRclocal
    [ $? -ne 0 ] && gDelayTime=1 && return 0

    # connect=<delay_time>,<debug_level>
    # connect=50    
    # connect=50,1
    local tmp=`echo "$1" | grep connect | cut -d'=' -f2`
    if [ ! -z $tmp ]; then
        gConnectOnce=1
        # Parser delay time for connect.sh
        local time=`echo "$tmp" | cut -d',' -f1`
        if [ ! -z $time ] && [ $time -ge 1 ] 2> /dev/null; then
            gDelayTime=$time
            Msg "Connect delay time: $gDelayTime"
        else
            gDelayTime=0
        fi

        # Parser debug level for connect.sh
        local debug=`echo "$tmp" | grep ',' | cut -d',' -f2`
        if [ ! -z $debug ] && [ $debug -ge 1 ] 2> /dev/null; then
            gConnectDebug=$debug
            Msg "Connect debug: $gConnectDebug"
        else
            gConnectDebug=0
        fi
    fi

    return 0
}

#====================================
#========== main function ===========
#====================================

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
# To parser arguments
#
for arg in $@
do
    [ $gConnectDebug -le 0 -a $gDelayTime -le 0 ] && CheckConnectFlag $arg
    [ $gDebug -le 0 ] && CheckDebugFlag $arg
done

#
# Connecting while booting 
#
if [ $gConnectOnce -eq 1 ]; then
    $gConnectScript "delay=$gDelayTime" > /dev/null
    #$gConnectScript "delay=$gDelayTime" "debug=$gConnectDebug" # for debug
    gRet=$?
    Msg "Connecting once after booting. ret: $gRet"
fi    

#
# Init monitor & log
#
Monitor_Init
Log_Init

#
# main loop
#
while :
do
    # Check monitor state is init or not
    Monitor_IsInit
    gRet=$?
    if [ $gRet -eq 0 ]; then
        Msg "Please to enable monitor.sh. Now go to sleep for 5 seconds.\n"
        #Msg "Please to enable monitor.sh. Now go to sleep for 60 seconds.\n"
        Monitor_SetState $M_SLEEP
        sleep 5 #60
        continue
    fi

    # Check monitor state is stop or not
    Monitor_IsStop
    gRet=$? && [ $gRet -eq 0 ] && break
    
    # Check monitor flag is enabled or not
    Monitor_IsEnable
    gRet=$?
    while [ $gRet -eq 0 ]
    do
        Log_GetLogLevel
        Monitor_SetState $M_RUN
        Msg "Running..."
        
        # Log timestamp
        Log_AddTimeStamp

        # Check & log with RSSI
        Msg "Update information..."
        ChkNLog_UpdateInfo
        gRet=$?
        if [ $gRet -eq $R_IP_GETSTATFAIL ] || [ $gRet -eq $R_IP_GETSNRFAIL ] || [ $gRet -eq $R_IP_PARSERFAIL ]; then
            if [ $gUpdateFailCnt -lt 3 ]; then 
		        MsgAndLog "Update information...($gRet)."
                gUpdateFailCnt=$((gUpdateFailCnt + 1))
            else
                MsgAndLog "Try to reconnect...(FailCnt: $gUpdateFailCnt)"
                gUpdateFailCnt=0

                Msg "Disconnecting..."
                $gConnectScript "stop"
                gRet=$?
                MsgAndLog "Disconnect done, ret: $gRet"
                sleep 1
                
                Msg "Reconnecting..."
                $gConnectScript
                gRet=$?
                MsgAndLog "Reconnect done, ret: $gRet"
            fi
        fi

        break
    done

    #
    # Set flag of monitor to sleep
    #
    Monitor_SetState $M_SLEEP

    Msg "Go to sleep for 5 seconds.\n"
    #Msg "Go to sleep for 60 seconds.\n"
    sleep 5
    #sleep 60
done

Msg "Monitor stop."
exit 0

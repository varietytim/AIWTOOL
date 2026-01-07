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
. $gCommonDir/module_var.sh

#
# Import modules
#
. $gCommonDir/common.sh
. $gCommonDir/debug.sh
. $gCommonDir/at_serial.sh
. $gCommonDir/module_err.sh # for at_serial.sh
. $gCommonDir/log.sh
. $gCommonDir/parser.sh
. $gCommonDir/monitor_ctrl.sh
. $gDriverCommonDir/script/mbim_var.sh

#
# Error code
#
R_IP_NETLOST=1
R_IP_NOTSYNC=2
R_IP_MODNULL=3
R_UNKNOW_USBMODE=4
R_IP_NOIP=5
R_IP_NOIFACE=6

#
# Other scripts
#
gToolCmd="$gWorkdir/tool.sh"
gDialoutScript=${gTopdir}/driver/dialout.sh

#
# Misc
#
gDialDebug=0
gDelayTime=0
gDialoutOnce=0

gRegRetryArgs="regcnt=30"

gUsbMode=0
gRegCnt=0
gFailCnt=0
gResetFlag=0
gDialFailCnt=0


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

ResetModule()
{
    if [ "$gCfgMtDisableReset" -eq 0 ]; then
        RunTool Init
        RunTool Reset
        MsgAndLog "Reset module..."
	    sleep 120
        RunTool Init
    else
        MsgAndLog "Not support to reset module, just clear flag."
    fi

    gResetFlag=0
}

CheckUSBMode()
{
    RunTool GetUsbMode
    local ret=$?
    if [ $ret -eq 0 ]; then
        local modeN=$(Log_GetVaule "$KEY_USBMODE")
        Dbg "modeN=$modeN"
        if [ $modeN -eq $gCfgRmNetUsbmode ]; then
            Msg "In RMNET Mode"
            return $gCfgRmNetUsbmode
        fi
        if [ $modeN -eq $gCfgMbimUsbmode ]; then
            Msg "In MBIM Mode"
            return $gCfgMbimUsbmode
        fi
        if [ $modeN -eq $gCfgRndisMode ]; then
            Msg "In RNDIS Mode"
            return $gCfgRndisMode
        fi
    fi

    return $ret
}

ChkLog_IP()
{
    local netip=''
    local modip=''
    local iface=''
    local tmp=''
    local tmp2=''
    local ret=1

    #
    # Give an interface with the usbmode
    #
    if [ "$gCfgHwIface" = "$IFTYPE_USB" ]; then
        Dbg3 "this: gUsbMode: $gUsbMode"
        if [ $gUsbMode -eq $gCfgRmNetUsbmode ]; then
        
            #
            # The first module to support RmNet mode for Fibocom module
            # e.g., AIW-355, AIW-344
            #
            tmp="$NETIF_GOBINET"
        
            #
            # Check if the flag of QMI WWAN is enabled
            # e.g., AIW-343 with QMI WWAN & RmNet mode
            #
            if [ ! -z $gCfgWWanEn ]; then
                if [ $gCfgWWanEn -eq 1 ]; then
                    tmp="$NETIF_QMI_WWAN"
                fi
            fi
        elif [ $gUsbMode -eq $gCfgRndisMode ]; then
            tmp="$NETIF_RNDIS"
        else
            tmp="$NETIF_MBIM"
        fi
    fi

    if [ "$gCfgHwIface" = "$IFTYPE_PCI" ]; then
        if [ $gUsbMode -eq $gCfgMbimUsbmode ]; then
            if [ ! -z "$gCfgCustomMbimIface" ]; then
                tmp="$gCfgCustomMbimIface" 
		if [ -e /dev/wwan0mbim0 ]; then
			tmp="wwan"
		fi	
            else
                tmp="$NETIF_MBIM"
            fi
        fi

        if [ $gUsbMode -eq $gCfgRndisMode ]; then
            if [ ! -z "$gCfgCustomRndisIface" ]; then
                RunTool GetNetInterface debug=3
                ret=$?
                if [ $ret -eq 0 ]; then
                    tmp=$(Log_GetVaule "$KEY_NETIFACE")
                    tmp2=1
                    Dbg "Get interface by AT command is $tmp"
                else
                    Dbg "Get interface with custom interface $gCfgCustomRndisIface"
                    tmp="$gCfgCustomRndisIface"
                fi
            else
                tmp="$NETIF_RNDIS"
            fi
        fi
    fi
           
    Common_iFindNetInterface "$tmp" "$tmp2"

    ret=$?
    if [ $ret -eq 0 ]; then
        iface="$gRetStr"
        Dbg "The network interface is $iface"
    else
        MsgAndLog "Not found the network interface ($tmp)."
        return $R_IP_NOIFACE
    fi

    Dbg "Get net IP"
    netip=`ifconfig "$iface" | grep -w "inet" | sed 's/^[ ]*//g' | cut -d' ' -f 2`
    if [ -z $netip ]; then
        MsgAndLog "Not found the IP address, connection is lost."
        return $R_IP_NETLOST
    else
        Dbg "NetIP($iface): $netip"
        Log_AddString "NetIP: $netip"
    fi

    Dbg "Get module IP"
    if [ $gUsbMode -eq $gCfgMbimUsbmode ] && [ $gCfgGetIpByMbim -eq 1 ]; then
        #
        # Get IP address by mbimcli, because the AT command is not supported to get IP
        # address in MBIM mode. e.g., AIW-357
        #
        Dbg3 "Get moudle IP by mbimcli, dev:$gCfgCdcWdm"
        MbimCli_iGetIp "$gCfgCdcWdm"
        if [ $? -eq 0 ]; then
            modip=$gRetStr
            Dbg "Get IP address by mbimcli is $modip"

            if [ "$modip" != "$netip" ]; then
                Dbg "Ip address, modip:$modip, netip:$netip"
                MsgAndLog "Net IP is not sync with module IP."
                Log_AddString "Module IP:$modip, Net IP:$netip"
                return $R_IP_NOTSYNC
            else
                Log_AddString "Module IP: $modip"
            fi
        else
            Dbg "Get IP address by mbimcli is failed, ret:$?"
            Log_AddString "Not found the IP address by mbimcli!"
            return $R_IP_NOTSYNC
        fi
    
    else 
        #
        # Get IP address by AT command
        #
        RunTool GetIP
        if [ $? -eq 0 ]; then
            modip=$(Log_GetVaule "$KEY_IP")
            if [ -z $modip ]; then
                Dbg "Module IP address is null!"
                Log_AddString "Module IP address is null!"
                return $R_IP_MODNULL
            fi
            Dbg "Get IP address by AT command is $modip"

            if [ "$modip" != "$netip" ]; then
                Dbg "Ip address, modip:$modip, netip:$netip"
                MsgAndLog "Net IP is not sync with module IP."
                Log_AddString "Module IP:$modip, Net IP:$netip"
                return $R_IP_NOTSYNC
            else
                Log_AddString "Module IP: $modip"
            fi
        else
            Log_AddString "Not found the module IP address!"
            return $R_IP_NOIP
        fi
    fi

    return 0
}

ChkNLog_RegStatus()
{
    local status;

    if [ $gUsbMode -eq $gCfgRmNetUsbmode ] || [ $gUsbMode -eq $gCfgRndisMode ]; then
        RunTool GetRegStatus
        if [ $? -eq 0 ]; then
            Log_AddCmdResult
            status=$(Log_GetVaule "$KEY_REGS")
            [ -z $status ] && Msg "Get value with $KEY_REGS is null!" && return 1
            #if [ $status -eq 1 ]; then
            if [ $status -eq 1 ] || [ $status -eq 4 ]; then
                return 0
            fi
        fi
    else
        MbimCli_iCheckReg "$gCfgCdcWdm"
        status=$?
        if [ $status -eq 0 ]; then
            Log_AddString "[MbimRegStatus] :$status"
            return 0
        fi
    fi

    Dbg "ChkNLog_RegStatus, not registration: $status"
    return 2
}

ChkNLog_Rssi()
{
    RunTool GetSignal
    if [ $? -eq 0 ]; then
        Log_AddCmdResult
        local status=$(Log_GetVaule "$KEY_RSSI")
        [ -z $status ] && Msg "Get value with $KEY_RSSI is null!" && return 1
        Dbg "ChkNLog_Rssi RSSI: $status"
        if [ $status -gt 0 ] && [ $status -ne 99 ]; then
            return 0
        fi
    fi

    Dbg "ChkNLog_Rssi, invalid RSSI: $status"
    return 2
}

ChkNLog_Sim()
{
    RunTool GetPin
    if [ $? -eq 0 ]; then
        Log_AddCmdResult
        local status=$(Log_GetVaule "$KEY_PIN")
        [ -z $status ] && Msg "Get value with $KEY_PIN is null!" && return 1
        #status=`echo $status | sed -e "s/.$//g"`
        Dbg "ChkNLog_Sim: $status"
        if [ "$status" = "READY" ]; then
            return 0
	    
        elif [ "$status" = "SIM" ] && [ ! -z $gCfgPinCode ]; then
            if [ "$gCfgModelName" = "Aiw357" ]; then
                  RunTool SetPin $gCfgPinCode
		  return 0
            else	
		RunTool SetPinUnlock $gCfgPinCode
		if [ $? -eq 0 ]; then
			RunTool SetPinLock $gCfgPinCode
			return 0
                fi
	    fi	
        fi
    fi

    Dbg "ChkNLog_Sim: $status"
    return 2
}

ChkNLog_WorkMode()
{
    #
    # Set APN first due to AIW-357
    #
    if [ $gCfgMtInitApn -eq 1 ]; then
        if [ $gUsbMode -eq $gCfgRndisMode ]; then
            RunTool SetApn $gCfgApn
            if [ $? -ne 0 ]; then
                Dbg2 "At command to set APN \"$gCfgApn\" failed"
                return 2
            fi
        fi 
    fi
    
    #
    # Force to set normal mode
    #
    RunTool SetNormalMode 1
    if [ $? -eq 0 ]; then
        #Log_AddCmdResult
        Dbg2 "Force to set normal mode"
        return 0
    else
        Dbg2 "Force to set normal mode failed"
    fi

    Dbg "ChkNLog_WorkMode: $status"
    return 3
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

CheckDialoutFlag()
{
    Monitor_IsBootDialForRclocal
    [ $? -ne 0 ] && gDelayTime=1 && return 0

    # dialout=<delay_time>,<debug_level>
    # dialout=50    
    # dialout=50,1
    local tmp=`echo "$1" | grep dialout | cut -d'=' -f2`
    if [ ! -z $tmp ]; then
        gDialoutOnce=1
        # Parser delay time for dialout.sh
        local time=`echo "$tmp" | cut -d',' -f1`
        if [ ! -z $time ] && [ $time -ge 1 ] 2> /dev/null; then
            gDelayTime=$time
            Msg "Dialout delay time: $gDelayTime"
        else
            gDelayTime=0
        fi

        # Parser debug level for dialout.sh
        local debug=`echo "$tmp" | grep ',' | cut -d',' -f2`
        if [ ! -z $debug ] && [ $debug -ge 1 ] 2> /dev/null; then
            gDialDebug=$debug
            Msg "Dialout debug: $gDialDebug"
        else
            gDialDebug=0
        fi
    fi

    return 0
}

CfgInit()
{
    #
    # Some AIW modules are not supported all configuration. we give an initial value
    # if the variable is null.
    #
    [ -z $gCfgRmNetUsbmode ] && gCfgRmNetUsbmode=0
    [ -z $gCfgRndisMode ] && gCfgRndisMode=0
    [ -z $gCfgHwIface ] && gCfgHwIface=$IFTYPE_USB
    [ -z $gCfgGetIpByMbim ] && gCfgGetIpByMbim=0
    [ -z $gCfgMtDisableReset ] && gCfgMtDisableReset=0
    [ -z $gCfgMtInitApn ] && gCfgMtInitApn=0
    [ -z $gCfgMtInitNormalMode ] && gCfgMtInitNormalMode=0
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
    [ $gDialDebug -le 0 -a $gDelayTime -le 0 ] && CheckDialoutFlag $arg
    [ $gDebug -le 0 ] && CheckDebugFlag $arg
done

#
# Init monitor & log
#
MErr_Init
Monitor_Init
Log_Init
CfgInit

#
# Dial out while booting 
#
while :
do
    # Check & log with device node that is used by other process or not
    AT_IsDevUse $gCfgExistPortSet
    if [ $? -eq 0 ]; then
            MsgAndLog "The device node of ttyUSBx is used by other process."
            sleep 3
            continue
    fi

    if [ $gDialoutOnce -eq 1 ]; then
        RunTool Init

        $gDialoutScript "delay=$gDelayTime" "debug=$gDialDebug" > /dev/null
        gRet=$?
        Msg "Dial out once after booting. ret: $gRet"
    fi
    break 
done

#
# main loop
#
while :
do
    # Check monitor state is init or not
    Monitor_IsInit
    gRet=$?
    if [ $gRet -eq 0 ]; then
        Msg "Please to enable monitor.sh. Now go to sleep for 60 seconds.\n"
        Monitor_SetState $M_SLEEP
        sleep 60
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

	# Check & log with device node that is used by other process or not
        AT_IsDevUse $gCfgExistPortSet
	if [ $? -eq 0 ]; then
	    MsgAndLog "The device node of ttyUSBx is used by other process."
        sleep 5
	    continue
	fi

        #
        # Check usbmode
        #
        if [ "$gCfgHwIface" = "$IFTYPE_USB" ]; then
            CheckUSBMode
            gUsbMode=$?
            if [ $gUsbMode -ne $gCfgRmNetUsbmode ] && [ $gUsbMode -ne $gCfgMbimUsbmode ] && [ $gUsbMode -ne $gCfgRndisMode ]; then
                MsgAndLog "Unexpected USB mode: $gUsbMode"
                RunTool Init
                break
            fi
        else
            gUsbMode=$gCfgUsbMode
        fi

        if [ $gUsbMode -eq $gCfgMbimUsbmode ]; then
		if [ ! -e "$gCfgCdcWdm" ]; then
                	DEVNAME=`dmesg | grep cdc-wdm | cut -d':' -f3 | awk '{print $1}' | tail -1`
                	gCfgCdcWdm="/dev/$DEVNAME"

		        if [ ! -e "$gCfgCdcWdm" ]; then
                            MsgAndLog "Device not exist..."
			    break
			fi    
        	fi
	fi	

        #
        # Checking the mode whether in normal mode or not
        # It's first time to support to AIW-357
        #
        #if [ $gUsbMode -eq $gCfgRndisMode ]; then
        if [ $gCfgMtInitNormalMode -eq 1 ]; then
            MsgAndLog "Checking mode..."
	    ChkNLog_WorkMode
            gRet=$?
            if [ $gRet -ne 0 ]; then
                 MsgAndLog "Checking mode failed, ret:$gRet"
		 break
            fi
        fi

        # Check & log with sim card
        Msg "Checking sim card is recognized..."
        ChkNLog_Sim
        if [ $? -ne 0 ]; then
            gFailCnt=$((gFailCnt + 1))
            MsgAndLog "Sim card is not recognized. (Cnt: $gFailCnt)"
            break
        fi
        
        # Log operator
        RunTool GetOperator
        Log_AddCmdResult
        
        # Check & log with RSSI
        Msg "Checking RSSI..."
        ChkNLog_Rssi
        if [ $? -ne 0 ]; then
            MsgAndLog "Invalid RSSI."
        fi
        
        # Check & log with registration status
        Msg "Checking registration status..."
        ChkNLog_RegStatus
        if [ $? -ne 0 ]; then
            if [ $gRegCnt -lt 3 ]; then
                MsgAndLog "No registration..."

		if [ "$gCfgModelName" = "Ewm341" ] && [ $gUsbMode -eq $gCfgRmNetUsbmode ]; then
                    break
                fi 
		
                $gDialoutScript "stop" "$gRegRetryArgs"
                gRet=$?
                MsgAndLog "Disconnect due to interface disabled, ret: $gRet"
                gFailCnt=$((gFailCnt + 1))
                gRegCnt=$((gRegCnt + 1))
            else
                MsgAndLog "Enable reset. (RegCnt: $gRegCnt, FailCnt: $gFailCnt)"
                gResetFlag=1
                gFailCnt=0
                gRegCnt=0
            fi
            
            Dbg "gRegCnt: $gRegCnt, gFailCnt: $gFailCnt"
            break
        else
            gFailCnt=0
            gRegCnt=0
            Dbg "gRegCnt: $gRegCnt, gFailCnt: $gFailCnt"
        fi

        # Check IP address
        Msg "Checking IP..."
        ChkLog_IP
        gRet=$?
        if [ $gRet -eq $R_IP_NOTSYNC ] || [ $gRet -eq $R_IP_NETLOST ]; then
            if [ $gRet -eq $R_IP_NOTSYNC ]; then
                Msg "Disconnect."
                $gDialoutScript "stop" "$gRegRetryArgs"
                gRet=$?
                MsgAndLog "Disconnect done, ret: $gRet"
            fi

            Msg "Reconnecting..."
            $gDialoutScript "$gRegRetryArgs"
            gRet=$?
            if [ $gRet -eq 0 ]; then
                MsgAndLog "Reconnect done, ret: $gRet"
                gDialFailCnt=0
            else
                if [ $gDialFailCnt -lt 2 ]; then
                    MsgAndLog "Reconnect failed, ret: $gRet"
                    gDialFailCnt=$((gDialFailCnt + 1))
                else
                    MsgAndLog "Enable reset. (DialFailCnt: $gDialFailCnt)"
                    gResetFlag=1
                    gDialFailCnt=0
                    break
                fi
                Dbg "gDialFailCnt: $gDialFailCnt"
            fi
        fi

        break
    done

    #
    # Set flag of monitor to sleep
    #
    Monitor_SetState $M_SLEEP

    #
    # Check reset or not
    #
    [ $gResetFlag -eq 1 ] && ResetModule

    Msg "Go to sleep for 15 seconds.\n"
    sleep 15 
    
done

Msg "Monitor stop."
exit 0

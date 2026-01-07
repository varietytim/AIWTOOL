#============================================================================
# Dial out script
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
. $gDriverCommonDir/script/mbim_var.sh
. $gDriverCommonDir/script/option_driver.sh

#
# Import modules
#
. $gCommonDir/common.sh
. $gCommonDir/debug.sh
. $gCommonDir/at_serial.sh
. $gCommonDir/log.sh
. $gCommonDir/parser.sh
. $gCommonDir/module_err.sh
. $gCommonDir/dialout_err.sh
. $gCommonDir/argument.sh

#
# To find the tool.sh
#
gToolCmd="$gToolDir/tool.sh"

#
# The run command
#
gRunCmd="none"

#
# Misc
#
DEF_REGTRYCNT=100
gProbeCnt=100
gRegTryCnt=$DEF_REGTRYCNT
gStartFlag=1
gDelayTime=0
gMbimDevNode=$gCfgCdcWdm
gWwanInf="$NETIF_MBIM"
gNetIfaceFlag=0


#====================================
#============ Functions =============
#====================================
RunTool()
{
    gRunCmd=$1
    $gToolCmd $@ > /dev/null

    local ret=$?
    return $ret
}

#
# Check registration status
#
CheckReg()
{
    local cnt;
    local mode="$2"
    local ii;
    local status;

    if [ -z $1 ]; then
        cnt=$gRegTryCnt
    else
        cnt=$1
    fi

    ii=0
    while :
    do
        if [ "$mode" = "GobiNet" ]; then
            RunTool GetRegStatus
            if [ $? -eq 0 ]; then
                status=$(Log_GetVaule "$KEY_REGS")
                if [ -z $status ]; then
                    gRet=$DErr_REGNULL
                    ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
                fi

                if [ $status -eq 1 ] || [ $status -eq 4 ]; then
                    return 0
                fi
            fi
        else
            MbimCli_iCheckReg "$gMbimDevNode" 
            [ $? -eq 0 ] && return 0
        fi

        if [ $ii -lt $cnt ]; then
            ii=$((ii+1))
        else
            gRet=$DErr_REG
            ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
        fi

        Msg "[$ii] Wait 3 seconds for registration"
        sleep 3
    done
}

CheckPin()
{
    RunTool GetPin
    if [ $? -eq 0 ]; then
        local status=$(Log_GetVaule "$KEY_PIN")
        Dbg "status: $status"
        if [ -z $status ]; then
            gRet=$DErr_PINNULL
            ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
        fi
        #status=`echo $status | sed -e "s/.$//g"`
        [ "$status" = "READY" ] && return 0
    fi

    return $DErr_PIN
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
    fi

    Msg "Unknow Mode"
    return $DErr_UNKNOWMODE
}

SetUsbMode()
{
    ${gModuleName}_iSetUsbMode $1
    local ret=$?
    if [ $ret -eq 0 ] || [ $ret -eq $MErr_ATNOPID ]; then
        Msg "Set to usbmode successful."
        Msg "Wait for $gCfgResetDelay seconds due to usbmode changed"
        sleep $gCfgResetDelay
        RunTool Init
        RunTool Reset
        Msg "Wait for $gCfgResetDelay seconds due to module reboot"
        sleep $gCfgResetDelay
    else
        Msg "Set to usbmode failed."
        return $DErr_SETMODE
    fi

    return 0
}

Option_LoadDriver()
{
    if [ ! -z $gCfgVendorId ] && [ ! -z $gCfgProductId ]; then
        OptionDrv_Load $gCfgVendorId $gCfgProductId
        Dbg "[ret:$?] Write the vendor ID:$gCfgVendorId & product ID:$gCfgProductId."
    fi

    if [ ! -z $gCfgVendorId2 ] && [ ! -z $gCfgProductId2 ]; then
        OptionDrv_Load $gCfgVendorId2 $gCfgProductId2 'append'
        Dbg "[ret:$?]: Write the vendor ID2:$gCfgVendorId2 & product ID2:$gCfgProductId2."
    fi
}

Option_UnLoadDriver()
{
    OptionDrv_UnLoad
}

GobiNet_IsDriverReady()
{
    local drive_name=`lsusb -t | grep "Driver=GobiNet" | awk -F, '{ printf $4 }' | cut -d '=' -f 2`
    if [ "$drive_name" = "GobiNet" ]; then
        Dbg "GobiNet is ready"
        return 0
    else
        Dbg "Not find GobiNet driver"
        return 1
    fi
}

GobiNet_LoadDriver()
{
    local ret;
    local end;
    local drver_ready;

    #
    # Remove option and reload the GobiNet driver
    #
    Option_UnLoadDriver

    end=10
    for i in $(seq 1 $end)
    do
        lsmod | grep qmi_wwan > /dev/null
        if [ $? -eq 0 ]; then
            Dbg "modprobe -r qmi_wwan"
            modprobe -r qmi_wwan
            sleep $gCfgUnLoadDelay
        fi

        modprobe GobiNet
        ExitIfError $? "modprobe GobiNet failed"
        Dbg "modprobe GobiNet"
        sleep $gCfgLoadDelay

        GobiNet_IsDriverReady
        if [ $? -eq 0 ]; then
            Dbg "[$i] Load GobiNet successful"
            drver_ready=0
            sleep 0.5
            break
        else
            modprobe -r GobiNet
            Dbg "modprobe -r GobiNet"
        fi
    
        drver_ready=1
        Dbg "[$i] Retry to load GobiNet, LoadDelay: $gCfgLoadDelay, UnLoadDelay: $gCfgUnLoadDelay"
        #if [ $i -eq 6 ] && [ "$gCfgModelName" = "Aiw344" ]; then
        #    Dbg "Reset module for Aiw344"
        #    RunTool Reset
        #    Msg "Wait for $gCfgResetDelay seconds due to module reboot"
        #    sleep $gCfgResetDelay 
        #else    
            sleep $gCfgUnLoadDelay
        #fi
    done

    #
    # Reload the option driver to enable the ttyUSBx
    #
    Option_LoadDriver

    return $drver_ready
}

Mbim_IsDriverReady()
{
    local drive_name=`lsusb -t | grep "Driver=cdc_mbim" | grep "Class=Communications" | awk -F, '{ printf $4 }' | cut -d '=' -f 2`
    if [ "$drive_name" = "cdc_mbim" ]; then
        Dbg "Mbim is ready"
        return 0
    else
        Dbg "Not find MBIM driver"
        return 1
    fi
}

Mbim_LoadDriver()
{
    local ret;
    local end;
    local drver_ready;

    #
    # Remove option and reload the MBIM driver
    #
    Option_UnLoadDriver

    end=10
    for i in $(seq 1 $end)
    do
        modprobe cdc_mbim
        ExitIfError $? "modprobe cdc_mbim failed"
        Dbg "modprobe cdc_mbim"
        sleep $gCfgLoadDelay

        Mbim_IsDriverReady
        if [ $? -eq 0 ]; then
            drver_ready=0
            Dbg "[$i] Load cdc_mbim successful"
            sleep 0.5
            break
        else
            modprobe -r cdc_mbim
            Dbg "modprobe -r cdc_mbim"
        fi

        drver_ready=1
        Dbg "[$i] Retry to load cdc_mbim, LoadDelay: $gCfgLoadDelay, UnLoadDelay: $gCfgUnLoadDelay"
        sleep $gCfgUnLoadDelay
    done

    #
    # Reload the option driver to enable the ttyUSBx
    #
    Option_LoadDriver

    return $drver_ready
}

Mbim2GobiNet()
{
    local ret;

    #
    # Down the network interface
    #
    Mbim_IsDriverReady
    if [ $? -eq 0 ]; then
        #Common_iFindNetInterface "wwan0"
        Common_iFindNetInterface "$NETIF_MBIM" "$gNetIfaceFlag"
        gWwanInf=$gRetStr

        local ret=`ifconfig | grep $gWwanInf | wc -l`
        if [ ! -z "$ret" ] && [ $ret -ge 1 ]; then
            Dbg "ifconfig $gWwanInf down"
            ifconfig $gWwanInf down
        fi
    fi

    #
    # Remove the MBIM driver
    #
    ret=`lsmod | grep cdc_mbim | wc -l`
    if [ ! -z $ret ] && [ $ret -ge 1 ]; then
        Dbg "modprobe -r cdc_mbim"
        modprobe -r cdc_mbim
    fi
    
    #
    # Set to MBIM mode
    #
    SetUsbMode $gCfgRmNetUsbmode
    if [ $? -eq 0 ]; then
        Msg "Set usbmode to rmnet success!"
    fi

    #
    # Reload the GobiNet driver
    #
    GobiNet_LoadDriver
    ret=$?

    return $ret
}

GobiNet2Mbim()
{
    #
    # Check GobiNet driver loaded or not
    #
    GobiNet_IsDriverReady
    if [ $? -eq 0 ]; then
        #Common_iFindNetInterface "usb0"
        Common_iFindNetInterface "$NETIF_GOBINET" "$gNetIfaceFlag"
        local iface="$gRetStr"
        Dbg "ifconfig down the interface of $iface with GobiNet"
        ifconfig "$iface" down 2> /dev/null

        Dbg "modprobe -r GobiNet"
        modprobe -r GobiNet
    fi

    #
    # Set to MBIM mode
    #
    SetUsbMode $gCfgMbimUsbmode
    if [ $? -eq 0 ]; then
        Msg "Set usbmode to mbim success!"
    fi

    #
    # Reload the MBIM driver
    #
    Mbim_LoadDriver
    ret=$?

    return $ret
}

SetAPN()
{
    RunTool SetApn $1
    if [ $? -ne 0 ]; then
        Dbg "At command failed with AT+CGDCONT=1,\"ip\",\"internet\""
        return $DErr_SETAPN
    fi

    return 0
}

SetAuthFromCfg()
{
    local apn_auth=''
    case $gCfgApnAuth in
        "NONE")
            apn_auth=0
            ;;

        "PAP")
            apn_auth=1
            ;;

        "CHAP")
            apn_auth=2
            ;;

        "PAP_CHAP")
            apn_auth=3
            ;;

        *)
            apn_auth=1
            ;;
    esac 

    if [ -z $gCfgUsername ] && [ -z $gCfgPassword ]; then
        Dbg "SetAuth 0 0 0"
        RunTool SetAuth 0 0 0
    else
        Dbg "SetAuth $gCfgUsername $gCfgPassword $apn_auth"
        RunTool SetAuth $gCfgUsername $gCfgPassword $apn_auth
    fi

    if [ $? -ne 0 ]; then
        Dbg "At command failed with AT+CGAUTH"
        return $DErr_SETAUTH
    fi

    return 0
}

SetPinUnlock()
{
    RunTool SetPinUnlock $1
    if [ $? -ne 0 ]; then
        Dbg "At command failed with AT+\"SC\",0,\"$1\""
        return $DErr_PINUNLOCK
    fi

    return 0
}

SetPinCode()
{
    RunTool SetPin $1
    if [ $? -ne 0 ]; then
        Dbg "At command failed with AT+CPIN=$1"
        return $DErr_SETPIN
    fi

    # Delay for sim ready    
    sleep 1

    return 0
} 

CheckLock()
{
  RunTool GetPinLock
  local ret=$?
  if [ $ret -ne 0 ]; then
	  if [ -n "$gCfgPinCode" ]; then
	      RunTool SetPinUnlock $gCfgPinCode
	      if [ $? -ne 0 ]; then	
		echo "Unlock SIM failed !"
		return -1
	      else
	        return 1	      
	      fi
      			      
	  fi
  fi
  return 0  
}

CheckUnLock()
{
  RunTool GetPinLock
  local ret=$?
  if [ $ret -ne 1 ]; then
          if [ -n "$gCfgPinCode" ]; then
              RunTool SetPinLock $gCfgPinCode
              if [ $? -ne 0 ]; then
                  echo "Lock SIM failed !"
	          return -1
              else
                  return 1  	
              fi
          fi
  fi
  return 0
}


CheckPinSet()
{
    local pinlog="$gPinLogFile"
    CheckLock
    local SIM_unlock=$?

    CheckPin
    local ret=$?
    if [ $ret -ne 0 ]; then
        Dbg "The pin code is not ready!"
    
        if [ -z $gCfgPinCode ]; then
            gRet=$DErr_NOPINCFG
            ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
        fi

        # Set pin code
        Common_iIsFileExist $pinlog
        ret=$?
        if [ $ret -eq 1 ]; then
            SetPinCode $gCfgPinCode
            ret=$?
            AT_LogToFile $pinlog
            if [ $ret -ne 0 ]; then
                gRet=$DErr_SETPIN
                ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
            else
                sleep 1
            fi

            SetPinUnlock $gCfgPinCode
            ret=$?
            if [ $ret -eq 0 ]; then
                Dbg "Unlock pin code succesful."
                sleep 1
            fi
        else
            gRet=$DErr_SETPINBYUSER
            ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
        fi
    fi

    if [ $SIM_unlock -eq 1 ]; then
        CheckUnLock
	if [ $? -ne 1 ]; then
             echo "SIM re-lock failed !"
	fi    
    fi

    return 0
}

Start()
{
    local mode=$1

    #
    # Check sim card
    #
    #${gModuleName}_iCheckSim
    #ExitIfError $? "Not find sim card!"

    CheckPinSet
    local ret=$?
    if [ $ret -ne 0 ]; then
        Dbg "Check pin set failed!"
    fi

    SetAPN "$gCfgApn"
    ret=$?
    if [ $ret -ne 0 ]; then
        Dbg "Set APN failed!"
    fi
   
    Dbg "SetAuth" 
    SetAuthFromCfg
    ret=$?
    if [ $ret -ne 0 ]; then
        Dbg "Set authentication failed!"
    fi

    #
    # Check registration status
    #
    CheckReg $gRegTryCnt "$mode"

    if [ "$mode" = "GobiNet" ]; then
        ${gModuleName}_iConnect
        ret=$?
        if [ $ret -ne 0 ]; then
            Dbg "Calling failed!"
            return $ret
        fi

        Msg "Enable GobiNet successful."
    else
        mbim-network "$gMbimDevNode" start
        $gSDir_MbimScript/mbim-set-ip "$gMbimDevNode" "$gWwanInf"
    fi

    return 0
}

Stop()
{
    local mode=$1
    local iface=''
    local ret=''

    if [ "$mode" = "GobiNet" ]; then
        GobiNet_IsDriverReady
        ret=$?
        if [ $ret -eq 0 ]; then
            #Common_iFindNetInterface "usb0"
            Common_iFindNetInterface "$NETIF_GOBINET" "$gNetIfaceFlag"
            iface="$gRetStr"
            Dbg "Get network interface is $iface with GobiNet"
        fi

        ${gModuleName}_iDisConnect
        ret=$?
        if [ $ret -ne 0 ]; then
            return $ret
        fi
        
        Msg "Stop GobiNet successful."
    else
        Mbim_DisConnect
        ret=$?
        if [ $ret -ne 0 ]; then
            return $ret
        fi

        iface="$gWwanInf"
        Msg "Stop MBIM successful."
    fi
        
    ip -4 addr flush dev $iface
    ip -6 addr flush dev $iface
    
    return 0
}

Mbim_DisConnect()
{
    mbim-network "$gMbimDevNode" stop
    ExitIfError $? "Stop $gMbimDevNode failed!"
    
    return 0
}

ReInitSerial()
{
    ProbeSerial $gProbeCnt $gCfgPortSet
    ExitIfError $? "Probe serial time out!"
    
    RunTool Init
    local ret=$?

    return $ret
}

GetUserInfo()
{
    if [ ! -z $gCfgApn ]; then
        Msg "APN is '$gCfgApn'"
    else
        gCfgApn=noapn
        Msg "Default APN is '$gCfgApn'"
    fi

    if [ ! -z $gCfgPinCode ]; then
        Msg "Pin Code is '$gCfgPinCode'"
    else
        Dbg "Default Pin Code is null"
    fi

    if [ $gCfgUsbMode -ne $gCfgMbimUsbmode ] && [ $gCfgUsbMode -ne $gCfgRmNetUsbmode ]; then    
        gCfgUsbMode=$gCfgRmNetUsbmode
        Msg "Default usbmode is '$gCfgUsbMode'"
    else
        Msg "Usbmode is '$gCfgUsbMode'"
    fi

    if [ ! -z $gCfgUsername ]; then
        Msg "Username is '$gCfgUsername'"
    fi
    
    if [ ! -z $gCfgPassword ]; then
        Msg "Password is '$gCfgPassword'"
    fi
    
    if [ ! -z $gCfgApnAuth ]; then
        Msg "Authentication type is '$gCfgApnAuth'"
    fi
}

#CheckDelayTime()
#{
#    local tmp=`echo "$1" | grep delay | cut -d'=' -f2`
#    if [ ! -z $tmp ] && [ $tmp -ge 1 ] 2> /dev/null; then
#        gDelayTime=$tmp
#        Dbg "Delay time: $gDelayTime"
#    else
#        gDelayTime=0
#    fi

#    return 0
#}

#CheckStopAction()
#{
#    [ ! -z $1 ] && [ "$1" = "stop" ] && gStartFlag=0 && Dbg "Stopping..."

#    return 0
#}

#CheckUpdateNetIface()
#{
#    [ ! -z $1 ] && [ "$1" = "netif" ] && gNetIfaceFlag=1 && Dbg "Update network interface."

#    return 0
#}

#CheckRegCnt()
#{
#    local tmp=`echo "$1" | grep regcnt | cut -d'=' -f2`
#    if [ ! -z $tmp ] && [ $tmp -ge 1 ] 2> /dev/null; then
#        gRegTryCnt=$tmp
#        Dbg "Reg retry count: $gRegTryCnt"
#    else
#        gRegTryCnt=100
#    fi

#    return 0
#}

########### main function ###########

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
# Init error code & log
#
MErr_Init
DErr_Init
Log_Init

#
# check model name
#
[ -z $gCfgModelName ] && Msg "Not find model name in configuration!" && exit 1
gModuleName=$gCfgModelName
Msg "Model: ${gModuleName}${gCfgMultiModelName}"

if [ "$gCfgModelName" != "${gWorkdir##*/}" ]; then
    Msg "The model name(${gWorkdir##*/}) isn't match with ${gCfgModelName}${gCfgMultiModelName}"
    Msg "Please go to setup again!"
    exit 0
fi

#
# Check & log with device node that is used by other process or not
#
AT_IsDevUse $gCfgExistPortSet
gRet=$?
if [ $gRet -eq 0 ]; then
    gRet=$DErr_DEVUSE   
    ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
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
    [ $gRegTryCnt -eq $DEF_REGTRYCNT ] && Arg_KvRegCnt $arg 'gRegTryCnt'
    [ $gNetIfaceFlag -eq 0 ] && Arg_NetIface $arg 'gNetIfaceFlag' '1'
done

#
# Wait for system init
#
Common_iCheckModuleID $gCfgVendorId $gCfgProductId
Is_Booting=$?
if [ $Is_Booting -ne 0 ]; then
      Common_iCheckModuleID $gCfgVendorId2 $gCfgProductId2
      Is_Booting=$?
fi

while [ $gDelayTime -ge 0 ]&&[ $Is_Booting -ne 0 ]; do
    sleep 1
    
    gDelayTime=$((gDelayTime-1))
    Common_iCheckModuleID $gCfgVendorId $gCfgProductId
    Is_Booting=$?
    if [ $Is_Booting -ne 0 ]; then
        Common_iCheckModuleID $gCfgVendorId2 $gCfgProductId2
        Is_Booting=$?
    fi
done

if [ $Is_Booting -ne 0 ] && [ $gDelayTime -le 0 ]; then
    Msg "Module Detect Timeout."
    exit 1
fi

#
# Get user config
#
GetUserInfo

#
# Enable devnode with driver "option"
#
AT_IsDevExist $gCfgExistPortSet
gRet=$?
[ $gRet -ne 0 ] && Option_LoadDriver

#
# Import module
#
if [ -e "$gModuleDir/$gModuleName/$gModuleName.sh" ] ;then
    . $gModuleDir/$gModuleName/$gModuleName.sh
    . $gCommonDir/module_var.sh
else
    gRet=$MErr_NOMODULE
    ExitIfError $gRet "($gRet) $(MErr_strCode2Msg $gRet)"
fi

#
# Init if not do it before
#
if [ ! -e $gModuleListFile ] || [ ! -e $gModuleCfgFile ]; then
    RunTool Init
    gRet=$?
    if [ $gRet -ge $MErr_Start ] && [ $gRet -le $MErr_End ]; then
        ExitIfError $gRet "($gRet) $(MErr_strCode2Msg $gRet)"
    else
        ExitIfError $gRet "($gRet) $gRetStr"
    fi
fi

#
# Get module config
#
. $gModuleCfgFile

#
# Check AT command & init serial
#
ReInitSerial
gRet=$?
if [ $gRet -ge $MErr_Start ] && [ $gRet -le $MErr_End ]; then
    ExitIfError $gRet "($gRet) $(MErr_strCode2Msg $gRet)"
else
    ExitIfError $gRet "($gRet) $gRetStr"
fi
Dbg "[main] gDevNode: $gDevNode"

#
# Enable log or not
#
Log_GetLogLevel
gRet=$? && [ $gRet -ge $L_LEVEL2 ] && AT_EnableLog
Log_AddString "\n<< Start to dialout >>\n"

#
# Get usbmode from module
#
while :
do
    CheckUSBMode
    gRet=$?
    if [ $gRet -ne 1 ]; then
        gRealUsbMode=$gRet
        break
    fi
    
    sleep 1
done
Dbg "Read USB mode: $gRealUsbMode"


#
# Running with GobiNet
#
if [ $gCfgUsbMode -eq $gCfgRmNetUsbmode ]; then
    if [ $gRealUsbMode -eq $gCfgMbimUsbmode ]; then
        Msg "Change to rmnet mode."
        Mbim2GobiNet
        ReInitSerial
    fi
    
    if [ $gRealUsbMode -ne $gCfgMbimUsbmode ] && [ $gRealUsbMode -ne $gCfgRmNetUsbmode ]; then
        Msg "Unexpected usbmode $gRealUsbMode"
    fi
   
    GobiNet_IsDriverReady
    gRet=$?
    if [ $gRet -ne 0 ]; then
        GobiNet_LoadDriver
        if [ $? -ne 0 ]; then 
            gRet=$DErr_LOADGBDRV
            ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
        fi
    fi
   
    #
    # Sync network interface with GobiNet driver
    #
    Common_iFindNetInterface "$NETIF_GOBINET"
    Common_iCheckNetIface $gRetStr
    gRet=$?
    if [ $gRet -ne 0 ]; then
        Common_iFindNetInterface "$NETIF_GOBINET" "1"
        Dbg "Update network interface with $gRetStr."
    fi
    
    #
    # Action to start or stop
    #
    if [ $gStartFlag -ne 0 ]; then
        Msg "Start GobiNet..."
        Start "GobiNet"
        gRet=$?
    else
        Msg "Stop GobiNet and disconnected."
        Stop "GobiNet"
        gRet=$?
    fi
fi

#
# Running with MBIM
#
if [ $gCfgUsbMode -eq $gCfgMbimUsbmode ]; then
    if [ $gRealUsbMode -eq $gCfgRmNetUsbmode ]; then
        Msg "Change to mbim mode."
        GobiNet2Mbim
        ReInitSerial
    fi
    
    if [ $gRealUsbMode -ne $gCfgMbimUsbmode ] && [ $gRealUsbMode -ne $gCfgRmNetUsbmode ]; then
        Msg "Unexpected usbmode $gRealUsbMode"
    fi

    Mbim_IsDriverReady
    if [ $? -ne 0 ]; then

        Mbim_LoadDriver
        if [ $? -ne 0 ]; then
            gRet=$DErr_LOADMBIMDRV
            ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
        fi
    fi

    Common_iFindNetInterface "$NETIF_MBIM" "2"
    gWwanInf=$gRetStr

    if [ ! -e "$gMbimDevNode" ]; then
        DEVNAME=`dmesg | grep cdc-wdm | cut -d':' -f3 | awk '{print $1}' | tail -1`
        Msg "Device /dev/$DEVNAME is detected."
        gMbimDevNode="/dev/$DEVNAME"
	if [ ! -e "$gMbimDevNode" ]; then
            gRet=$DErr_NOMDEV
            ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
	fi
    fi

    #
    # Action to start or stop
    #
    if [ $gStartFlag -ne 0 ]; then
        Msg "Start Mbim..."
        Start "Mbim"
        gRet=$?
    else
        Msg "Stop Mbim and disconnected."
        Stop "Mbim"
        gRet=$?
    fi
fi

Msg "Dialout complete."
exit $gRet


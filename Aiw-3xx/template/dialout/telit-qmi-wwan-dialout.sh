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
. $gCommonDir/qmi_wwan.sh
. $gDriverCommonDir/script/option_driver.sh
. $gDriverCommonDir/script/qmi_wwan_driver.sh

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
gQmiDevNode=$gCfgCdcWdm
gWwanInf="$NETIF_QMI_WWAN"
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
    local cnt
    if [ -z $1 ]; then
        cnt=$gRegTryCnt
    else
        cnt=$1
    fi    
    local ii=0

    while :
    do
        RunTool GetRegStatus
        if [ $? -eq 0 ]; then
            local status=$(Log_GetVaule "$KEY_REGS")
            if [ -z $status ]; then
                gRet=$DErr_REGNULL
                ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
            fi

            #
            # 1: registered, home network
            # 4: out of LTE coverage, downgrade to 3G
            #
            if [ $status -eq 1 ] || [ $status -eq 4 ]; then
                return 0
            fi
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
        #Dbg "status: $status"
        #echo $status | hexdump
        [ "$status" = "READY" ] && return 0
    fi

    return $DErr_PIN
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
        Dbg "At command failed with authentication"
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
    local lock;
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
    local ret;

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
  
    #Dbg "SetAuth"
    #SetAuthFromCfg
    #ret=$?
    #if [ $ret -ne 0 ]; then
    #    Dbg "Set authentication failed!"
    #fi

    #
    # Check registration status
    #
    CheckReg $gRegTryCnt

    #
    # Start to run QMI network 
    #
    Dbg "Check status with QMI network"
    Qmi_iCheckStatus "$gQmiDevNode"
    if [ $? -ne 0 ]; then
        Dbg "Stop QMI network due to no connection"
        Qmi_iStop "$gQmiDevNode" "$gWwanInf"
        ExitIfError $? "Stop QMI network failed."
    
        Dbg "Start QMI network..."
        Qmi_iStart "$gQmiDevNode"
        if [ $? -ne 0 ]; then
            RunTool Reset
            Msg "Reset module and please waiting for 20 seconds"
            sleep 20
            CheckReg $gRegTryCnt
            Qmi_iStart "$gQmiDevNode"
            ExitIfError $? "Start QMI network failed."
        fi
    else
        Dbg "QMI network is already connected."
    fi

    Qmi_iSetIP "$gQmiDevNode" "$gWwanInf"
    ExitIfError $? "Set IP address failed."

    return 0
}

Stop()
{
    Qmi_iStop "$gQmiDevNode" "$gWwanInf"
    local ret=$?
    if [ $ret -ne 0 ]; then
        return $ret
    fi

    Msg "Stop QMI WWAN successful."
        
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

CheckDelayTime()
{
    local tmp=`echo "$1" | grep delay | cut -d'=' -f2`
    if [ ! -z $tmp ] && [ $tmp -ge 1 ] 2> /dev/null; then
        gDelayTime=$tmp
        Dbg "Delay time: $gDelayTime"
    else
        gDelayTime=0
    fi

    return 0
}

CheckStopAction()
{
    [ ! -z $1 ] && [ "$1" = "stop" ] && gStartFlag=0 && Dbg "Stopping..."

    return 0
}

CheckUpdateNetIface()
{
    [ ! -z $1 ] && [ "$1" = "netif" ] && gNetIfaceFlag=1 && Dbg "Update network interface."

    return 0
}

CheckRegCnt()
{
    local tmp=`echo "$1" | grep regcnt | cut -d'=' -f2`
    if [ ! -z $tmp ] && [ $tmp -ge 1 ] 2> /dev/null; then
        gRegTryCnt=$tmp
        Dbg "Reg retry count: $gRegTryCnt"
    else
        gRegTryCnt=100
    fi

    return 0
}

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
Msg "Model: $gModuleName"

if [ "$gCfgModelName" != "${gWorkdir##*/}" ]; then
    Msg "The model name(${gWorkdir##*/}) isn't match with $gCfgModelName"
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

    [ $gDelayTime -le 0 ] && CheckDelayTime $arg
    [ $gStartFlag -eq 1 ] && CheckStopAction $arg
    [ $gRegTryCnt -eq $DEF_REGTRYCNT ] && CheckRegCnt $arg
    [ $gNetIfaceFlag -eq 0 ] && CheckUpdateNetIface $arg
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
# Check the driver is ready or not
#
QmiDrv_IsDriverReady

if [ $? -ne 0 ]; then
    Dbg2 "Load qmi_wwan driver"
    QmiDrv_LoadDriver
    if [ $? -ne 0 ]; then
        gRet=$DErr_LOADQMIDRV
        ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
    fi
    Dbg2 "Delay 3 seconds after driver loaded"
    sleep 3
fi

Common_iFindNetInterface "$NETIF_QMI_WWAN" "2"
gWwanInf=$gRetStr

#
# Check the device node is exist or not
#
if [ ! -e "$gQmiDevNode" ]; then
    gRet=$DErr_NOMDEV
    ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
fi

#
# Action to start or stop
#
if [ $gStartFlag -ne 0 ]; then
    echo Y > /sys/class/net/$gWwanInf/qmi/raw_ip
    Msg "Start QMI network..."
    Start
    gRet=$?
else
    Msg "Stop QMI network and disconnected."
    Stop
    gRet=$?
fi

Msg "Dialout complete."
exit $gRet


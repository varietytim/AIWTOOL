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
. $gCommonDir/mbim.sh
. $gDriverCommonDir/script/mbim_var.sh
. $gDriverCommonDir/script/mbim_driver.sh
. $gDriverCommonDir/script/option_driver.sh
. $gDriverCommonDir/script/rndis_driver.sh
. $gDriverCommonDir/script/ubuntu_nmcli.sh

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

DEVNAME=`dmesg | grep cdc-wdm | cut -d':' -f3 | awk '{print $1}' | tail -1`
gCfgCdcWdm="/dev/$DEVNAME"
gMbimDevNode=$gCfgCdcWdm

if [ "$gCfgHwIface" = "$IFTYPE_PCI" ] && [ -e /dev/wwan0mbim0 ]; then
         gCfgCdcWdm="/dev/wwan0mbim0"
         gMbimDevNode="/dev/wwan0mbim0"
fi


#
# About network interface
#
gNetIfaceFlag=0
gCurRndisIface="$NETIF_RNDIS"
gCurMbimIface="$NETIF_MBIM"
if [ "$gCfgHwIface" = "$IFTYPE_PCI" ] && [ ! -z "$gCfgCustomMbimIface" ]; then
    gDefMbimIface=$gCfgCustomMbimIface
    gCurMbimIface=$gCfgCustomMbimIface
    Dbg3 "Renew default interface with MBIM to $gDefMbimIface due to custom interface in config."
else
    gDefMbimIface="$NETIF_MBIM"
fi


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
        if [ "$mode" = "MODE_RNDIS" ]; then
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

	    RunTool SetEIAApn "$gCfgApn"
	    sleep 10
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
        Dbg "Pin status: $status"
        if [ -z $status ]; then
            gRet=$DErr_PINNULL
            ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
        fi
        
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
        if [ $modeN -eq $gCfgRndisMode ]; then
            Msg "In RNDIS Mode"
            return $gCfgRndisMode
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
    local ret;
    local ii;

    ii=0
    while :
    do
        OptionDrv_UnLoad
        ret=$?
        if [ $ret -eq 0 ]; then
            break
        else
            ii=$((ii+1))
            sleep 1
        fi

        if [ $ii -ge 5 ]; then
            ExitIfError $ret "Unload option driver failed!"
        fi
    done
}

Mbim_LoadDriver()
{
    #
    # Remove option and reload the MBIM driver
    #
    Option_UnLoadDriver

    #
    # Load the MBIM driver
    #
    MbimDrv_LoadDriver 0.5

    #
    # Reload the option driver to enable the ttyUSBx
    #
    Option_LoadDriver
    ReInitSerial
}

Rndis_LoadDriver()
{
    #
    # Remove option and reload the rndis driver
    #
    Option_UnLoadDriver

    #
    # Load the rndis driver
    #
    RndisDrv_LoadDriver 0.5

    #
    # Reload the option driver to enable the ttyUSBx
    #
    Option_LoadDriver
    
    ReInitSerial
}

Mbim2Rndis()
{
    local ret;

    #
    # Down the network interface
    #
    MbimDrv_IsDriverReady
    if [ $? -eq 0 ]; then
        Common_iFindNetInterface "$gDefMbimIface" "$gNetIfaceFlag"
        gCurMbimIface=$gRetStr

        local ret=`ifconfig | grep $gCurMbimIface | wc -l`
        if [ ! -z "$ret" ] && [ $ret -ge 1 ]; then
            Dbg "ifconfig $gCurMbimIface down"
            ifconfig $gCurMbimIface down
        fi
    fi

    #
    # Remove the MBIM driver
    #
    MbimDrv_UnloadDriver

    #
    # Set to MBIM mode
    #
    SetUsbMode $gCfgRndisMode
    if [ $? -eq 0 ]; then
        Msg "Set usbmode to rndis success."
    else
        Msg "Set usbmode to randis failed!"	    
    fi

    return 0
}

Rndis2Mbim()
{
    #
    # Set to MBIM mode without removed RNDIS driver
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

PCI_LoadDriver()
{
    local drv_name="${1%\.ko}"

    local search_driver=$(lsmod | grep "$drv_name")
    local driver="${search_driver%% *}"    
    if [ -z "$driver" ]; then
        modprobe ${drv_name}
        if [ $? -eq 0 ]; then
            Msg "Load the driver $drv_name"
            sleep 1
        else
            Msg "Load the driver $drv_name failed"
            return $DErr_LOADPCIDRV
        fi
    fi

    return 0
}

SetAPN()
{
    Dbg "Set APN $1"
    RunTool SetApn $1
    if [ $? -ne 0 ]; then
        Dbg "At command to set APN \"$1\" failed"
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
        SetPinCode $gCfgPinCode
        ret=$?
        AT_LogToFile $pinlog
        if [ $ret -ne 0 ]; then
            gRet=$DErr_SETPIN
            ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
        else
            sleep 1
        fi
    fi

    return 0
}

Start()
{
    local mode=$1
    local iface;
    local module_ip;
    local def_gateway;
    local p_dns;
    local s_dns;

    #
    # Set init APN with RNDIS
    #
    if [ "$mode" = "MODE_RNDIS" ]; then
        #
        # Before to set init APN, we need to set cfun to 0 as default to make sure
        # the connection is created normally.
        #
        if [ "$gCfgHwIface" = "$IFTYPE_PCI" ]; then
            Dbg3 "Force to set station off mode due to PCIe"
            RunTool SetStationOffMode 1
            sleep 1
        fi

        #
        # Set init APN
        #
        SetAPN "$gCfgApn"
        ret=$?
        if [ $ret -ne 0 ]; then
            Dbg "Set init APN failed!"
        fi

        Dbg "SetAuth"
        SetAuthFromCfg
        ret=$?
        if [ $ret -ne 0 ]; then
            Dbg "Set authentication failed!"
        fi
    fi

    #
    # With RNDIS protocol by USB interface and with both protocols by PCIe interface,
    # we need to make sure the module set to  normal mode. Because AIW-357 is set to 
    # cfun=0 as default when boot or reset.
    #
    if [ "$gCfgHwIface" = "$IFTYPE_PCI" ] || [ "$mode" = "MODE_RNDIS" ]; then
        Dbg3 "Force to set normal mode."
        RunTool SetNormalMode 1
        sleep 1
    fi

    CheckPinSet
    local ret=$?
    if [ $ret -ne 0 ]; then
        Dbg "Check pin set failed!"
    fi
    
    #
    # Check registration status
    #
    if [ $gRegTryCnt -eq 1 ]; then
        gRegTryCnt=5
        Dbg3 "Change reg cnt from 1 to $gRegTryCnt"
    fi 
    CheckReg $gRegTryCnt "$mode"

    #
    # Create connection
    #
    if [ "$mode" = "MODE_RNDIS" ]; then
        ${gModuleName}_iConnect
        ret=$?
        if [ $ret -ne 0 ]; then
            Dbg "Calling failed!"
            return $ret
        fi

        #
        # RNDIS by PCIe interface
        #
        if [ "$gCfgHwIface" = "$IFTYPE_PCI" ] && [ ! -e /dev/wwan0at0 ]; then

            RunTool GetNetInterface
            ret=$?
            if [ $ret -eq 0 ]; then
                gCurRndisIface=$(Log_GetVaule "$KEY_NETIFACE")
                Dbg3 "Renew interface by AT command is $gCurRndisIface"
            else
                gCurRndisIface="$gCfgCustomRndisIface" #ccmni1
                Dbg3 "Renew interface with custom interface $gCfgCustomRndisIface"
            fi
        else
	    Common_iFindNetInterface "$NETIF_RNDIS" "1"
	    gRet=$?
	    if [ $gRet -eq 0 ]; then
		 gCurRndisIface=$gRetStr
	    fi	
            Dbg3 "Renew interface with custom interface $gCurRndisIface"
        fi
        
        #
        # Get IP address from module
        #
        RunTool GetIP
        ret=$?
        if [ $ret -eq 0 ]; then
            module_ip=$(Log_GetVaule "$KEY_IP")
            if [ -z "$module_ip" ]; then
                Dbg "Module IP address is null!"
                return $ret
            fi
        else
            Dbg "Get IP address failed, ret: $ret"
            return $ret
        fi

        if [ "$module_ip" != "0.0.0.0" ]; then
            Dbg "Get IP address <$module_ip> from module"
        else
            Dbg3 "Get IP address is 0.0.0.0 and exit"
            return 1
        fi
        
        #
        # Parser and output default gateway
        #
        ret=`echo $module_ip | cut -d'.' -f4`
        ret=$((ret+1))

        def_gateway=`echo ${module_ip%.*}.$ret`
        Dbg3 "module_ip: $module_ip, def_gateway: $def_gateway"

        #
        # Get DNS from module
        #
        ${gModuleName}_iGetDns
        ret=$?
        if [ $ret -eq 0 ]; then
            p_dns=$(Log_GetVaule "$KEY_PDNS")
            if [ -z $p_dns ]; then
                Dbg "Primary DNS is null!"
                return $ret
            fi

            s_dns=$(Log_GetVaule "$KEY_SDNS")
            if [ -z $s_dns ]; then
                Dbg "Secondary DNS is null, replace it to default DNS!"
                s_dns="8.8.8.8"
            fi
        fi
        Dbg "Get DNS from module, primary DNS: $p_dns, secondary DNS: $s_dns"

        Common_iSetIpRoute $gCurRndisIface $module_ip $def_gateway "$p_dns" "$s_dns"
        ret=$?
        if [ $ret -ne 0 ]; then
            return $ret
        fi

	Monitor_IsEnable
	ret=$?
	if [ $ret -ne 0 ]; then
	    RunTool EnableMonitor
	    systemctl restart rc-local
	fi

        Msg "Enable RNDIS successful."
    else
        Dbg3 "gMbimDevNode: $gMbimDevNode, gCurMbimIface: $gCurMbimIface"
        Mbim_iStart "$gMbimDevNode"
        Mbim_iSetIP "$gMbimDevNode" "$gCurMbimIface"
    fi

    return $?
}

Stop()
{
    local mode=$1
    local iface=''
    local ret=''

    #
    # Stop connection
    #
    if [ "$mode" = "MODE_RNDIS" ]; then
        if [ "$gCfgHwIface" = "$IFTYPE_USB" ]; then
            RndisDrv_IsDriverReady
            ret=$?
            if [ $ret -eq 0 ]; then
                Common_iFindNetInterface "$NETIF_RNDIS" "$gNetIfaceFlag"
                iface="$gRetStr"
                Dbg "Get network interface is $iface with RNDIS"
            fi
        else
            RunTool GetNetInterface
            iface=$(Log_GetVaule "$KEY_NETIFACE")
            if [ ! -z "$iface" ]; then
                Dbg3 "Renew interface by AT command is $iface"
            else
                Dbg3 "Renew interface with custom interface $gCfgCustomRndisIface"
                iface="$gCfgCustomRndisIface"
            fi
        fi
        
        ${gModuleName}_iDisConnect
        ret=$?
        if [ $ret -ne 0 ]; then
            return $ret
        fi

       
        Dbg "ifconfig $iface 0.0.0.0 to clean IP address"
        ifconfig $iface 0.0.0.0 
        
        Msg "Stop RNDIS successful."
    else
        Mbim_DisConnect
        ret=$?
        if [ $ret -ne 0 ]; then
            return $ret
        fi

        iface="$gCurMbimIface"
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

    if [ $gCfgUsbMode -ne $gCfgMbimUsbmode ] && [ $gCfgUsbMode -ne $gCfgRndisMode ]; then    
        gCfgUsbMode=$gCfgRndisMode
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
# Wait for system init
#
for i in $(seq 1 10)
do
    if [ $i -ne 1 ]; then
        eval _VID=\${gCfgVendorId$i}
        eval _PID=\${gCfgProductId$i}
    else
        _VID=$gCfgVendorId
        _PID=$gCfgProductId
    fi
    
    if [ -z "$_VID" ]; then
        continue
    fi
    
    Common_iCheckModuleID $_VID $_PID $gCfgHwIface
    Is_Booting=$?
    if [ $Is_Booting -eq 0 ]; then
        break
    fi
done

while [ $gDelayTime -ge 0 ]&&[ $Is_Booting -ne 0 ]; do
    sleep 1
    gDelayTime=$((gDelayTime-1))

    for i in $(seq 1 10)
    do
        if [ $i -ne 1 ]; then
            eval _VID=\${gCfgVendorId$i}
            eval _PID=\${gCfgProductId$i}
        else
            _VID=$gCfgVendorId
            _PID=$gCfgProductId
        fi
        
        if [ -z "$_VID" ]; then
            continue
        fi

        Common_iCheckModuleID $_VID $_PID $gCfgHwIface
        Is_Booting=$?
        if [ $Is_Booting -eq 0 ]; then
            break
        fi
    done
done

if [ $Is_Booting -ne 0 ] && [ $gDelayTime -le 0 ]; then
    Msg "Module Detect Timeout."
    exit 1
fi

if [ "$gCfgHwIface" = "$IFTYPE_PCI" ] && [ -e /dev/wwan0at0 ] && [ ! -e /dev/ttyC0 ]; then
        ln -s /dev/wwan0at0 /dev/ttyC0
        ln -s /dev/wwan0mbim0 /dev/ttyCMBIM0
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
if [ "$gCfgHwIface" = "$IFTYPE_PCI" ]; then
    if [ $gRet -ne 0 ]; then
        PCI_LoadDriver $gCfgDriverName
        gRet=$?
        ExitIfError $gRet "($gRet) $(MErr_strCode2Msg $gRet)"
    fi
else
    [ $gRet -ne 0 ] && Option_LoadDriver
fi

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
if [ "$gCfgHwIface" = "$IFTYPE_USB" ]; then
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
# With PCIe mode on AIW-357, we make gRealUsbMode the same as gCfgUsbMode
# because MBIM and RNDIS are used to PCIe mode only.
# 
else
    gRealUsbMode=$gCfgUsbMode
    Dbg "Protocol with PCIe mode: $gRealUsbMode"
fi

#
# Running with RNDIS
#
if [ $gCfgUsbMode -eq $gCfgRndisMode ]; then
    #
    # This block is only checked to USB interface
    #
    if [ $gRealUsbMode -eq $gCfgMbimUsbmode ]; then
        Msg "Change to RNDIS mode."
        Mbim2Rndis
        ReInitSerial
    fi
   
    if [ $gRealUsbMode -ne $gCfgMbimUsbmode ] && [ $gRealUsbMode -ne $gCfgRndisMode ]; then
        Msg "Unexpected protocol mode $gRealUsbMode"
        gRet=$DErr_UNKNOWMODE
        ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
    fi
 
    #
    # RNDIS by USB interface
    #
    if [ "$gCfgHwIface" = "$IFTYPE_USB" ]; then 
        RndisDrv_IsDriverReady
        gRet=$?
        if [ $gRet -ne 0 ]; then
            Rndis_LoadDriver
            if [ $? -ne 0 ]; then 
                gRet=$DErr_LOADGBDRV
                ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
            fi
        fi
   
        #
        # Sync network interface with RNDIS
        #
        Common_iFindNetInterface "$NETIF_RNDIS"
        Common_iCheckNetIface $gRetStr
        gRet=$?
        if [ $gRet -ne 0 ]; then
            Common_iFindNetInterface "$NETIF_RNDIS" "1"
            Dbg "Update network interface with $gRetStr."
        fi
        gCurRndisIface=$gRetStr

        #
        # Disable auto connection
        #
        Nmcli_iDisableAutoConnect $gCurRndisIface
        Dbg3 "Disable auto connection with $gCurRndisIface, ret: $gRet"
    fi 

    #
    # Action to start or stop
    #
    if [ $gStartFlag -ne 0 ]; then
        Msg "Start RNDIS..."
        Start "MODE_RNDIS"
        gRet=$?
    else
        Msg "Stop RNDIS and disconnected."
        Stop "MODE_RNDIS"
        gRet=$?
    fi
fi

#
# Running with MBIM
#
if [ $gCfgUsbMode -eq $gCfgMbimUsbmode ]; then
    #
    # This block is only checked to USB interface
    #

    if [ $gRealUsbMode -eq $gCfgRndisMode ]; then
        Msg "Change to mbim mode."
        Rndis2Mbim
	DEVNAME=`dmesg | grep cdc-wdm | cut -d':' -f3 | awk '{print $1}' | tail -1`
        Msg "Device /dev/$DEVNAME is detected."
	gMbimDevNode="/dev/$DEVNAME"

        if [ "$gCfgHwIface" = "$IFTYPE_PCI" ] && [ -e /dev/wwan0mbim0 ]; then
            gMbimDevNode="/dev/wwan0mbim0"
        fi
	
        ReInitSerial
    fi

    
    if [ $gRealUsbMode -ne $gCfgMbimUsbmode ] && [ $gRealUsbMode -ne $gCfgRndisMode ]; then
        Msg "Unexpected usbmode $gRealUsbMode"
        gRet=$DErr_UNKNOWMODE
        ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
    fi

    #
    # MBIM by USB interface
    #
    if [ "$gCfgHwIface" = "$IFTYPE_USB" ]; then
        MbimDrv_IsDriverReady
        if [ $? -eq 0 ]; then
            Common_iFindNetInterface "$gDefMbimIface" "$gNetIfaceFlag"
            gCurMbimIface=$gRetStr
        else
            Mbim_LoadDriver
            if [ $? -ne 0 ]; then
                gRet=$DErr_LOADMBIMDRV
                ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
            fi
	    Common_iFindNetInterface "$gDefMbimIface" "$gNetIfaceFlag"
            gCurMbimIface=$gRetStr

        fi

	DEVNAME=`dmesg | grep cdc-wdm | cut -d':' -f3 | awk '{print $1}' | tail -1`
        Msg "Device /dev/$DEVNAME is detected."
        gMbimDevNode="/dev/$DEVNAME"

    fi

    #
    # Check the device node is exist or not
    #
    if [ ! -e "$gMbimDevNode" ]; then
        gRet=$DErr_NOMDEV
        ExitIfError $gRet "($gRet) $(DErr_strCode2Msg $gRet)"
    fi

    #
    # Turn on radio with MBIM mode
    # 
    
    if [ "$gCfgHwIface" = "$IFTYPE_PCI" ]; then
	 if [ -e /dev/wwan0mbim0 ]; then
             gMbimDevNode="/dev/wwan0mbim0"
         elif [ -e /dev/ttyCMBIM0 ]; then 
		 gMbimDevNode="/dev/ttyCMBIM0"
         fi
    fi
     
    Mbim_iTurnOnRadio "$gMbimDevNode"
    gRet=$?
    Dbg3 "Mbim_iTurnOnRadio ret:$ret, gRetStr:$gRetStr"
    if [ $gRet -eq 0 ]; then
        if [ "$gRetStr" = "$RADIO_ON" ]; then
            Msg "Turn on the radio and waiting for 60 seconds"
            sleep 60
        fi
    else
        Msg "Turn on the radion failed. ret:$gRet"
        exit 1
    fi

    #
    # Action to start or stop
    #
    if [ $gStartFlag -ne 0 ]; then
        Msg "Start MBIM..."
	NOT_READY=`mbimcli -d $gMbimDevNode --query-subscriber-ready-status --device-open-proxy | grep "Ready info" | cut -d: -f2 | grep unknown | wc -l`
	if [ $NOT_READY -eq 1  ]; then
                RunTool Reset
                Msg "Waiting for $gCfgResetDelay seconds for system initialization..."
                sleep $gCfgResetDelay
        	ReInitSerial
                RunTool SetNormalMode 1
                sleep 1
		MbimDrv_UnloadDriver
		sleep 1
		Mbim_LoadDriver
		sleep 1
	fi	
        Start "MODE_MBIM"
        gRet=$?
    fi
fi

Msg "Dialout complete."
exit $gRet


#!/bin/sh

. $gCommonDir/monitor_ctrl.sh
. $gCommonDir/module_err.sh

#
# This delay is due to PCIe response
#
if [ ! -z $gCfgAtCmdDelay ]; then
gAtCmdDelay=$gCfgAtCmdDelay
fi

#==============================================
#=============== Local function ===============
#==============================================
Aiw357_l_WriteCfg()
{
    local data="$1"

    if [ ! -z $2 ] && [ "$2" = "append" ]; then
        echo "$1" >> $gModuleCfgFile
    else        
        echo "$1" > $gModuleCfgFile
    fi

    if [ $? -eq 0 ]; then
        return 0
    else
        return $MErr_WDEVNODE
    fi
}

Aiw357_l_Help()
{
    echo "Usage: $0 $gRunCmd $@"
}

#
# Send the AT+CFUN
# $1: the number of function
# $2: 0 or null: checking monitor before set function
#     1: force to set function, 0 or null: checking monitor before set function
#
Aiw357_l_ATCfunc()
{
    local force_en=${2:-0}
    Dbg3 "Aiw357_l_ATCfunc"

    if [ $force_en -ne 1 ]; then
        Monitor_GetState
        local ret=$?
        if [ $ret -eq $M_RUN ]; then
            gRetStr=$(MErr_strCode2Msg $MErr_MTRRUN)
            return $ret
        fi
    fi

    ATCOMM "AT+CFUN=$1" $gAtCmdDelay
    ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    return 0
}

#==============================================
#================ API function ================
#==============================================
#
# The below is alias to define USB mode
# MBIM:29 , RNDIS: 13
#
# AT command to get USB mode as below:
# MBIM  mode: AT+EGMC=1,"usb_mode",1,1
# RNDIS mode: AT+EGMC=1,"usb_mode",1,0
# qurey     : AT+EGMC=0,"usb_mode"
#
Aiw357_iSetUsbMode()
#Aiw357_SetUsbMode()
{
    local tmp='AT+EGMC=1,\"usb_mode\",1,mode_num';

    [ -z $1 ] && return $MErr_NULL
    
    if [ $1 -eq 29 ]; then
        tmp=`echo "$tmp" | sed -e "s/mode_num/1/g"`
    elif [ $1 -eq 13 ]; then
        tmp=`echo "$tmp" | sed -e "s/mode_num/0/g"`
    else
        Msg "Unsupported usbmode $1"
        return $MErr_USBMODEARG
    fi

    ATCOMM $tmp
    local ret=$?
    if [ $ret -ne 0 ]; then
        #Msg "Set to usbmode failed."
        gRetStr="AT error!"
        return $ret
    fi

    # Reset module
    Aiw357_l_ATCfunc 15
    local ret=$?
    if [ $ret -ne 0 ]; then
        return $ret
    fi

    return 0
}

#Aiw357_iInitRndis()
#{
    # option 1
    # Help information with this command
    #[ $# -le 0 ] && Aiw357_l_Help '[apn_string]' && return 0

    #if [ ! -z "$1" ]; then
    #    [ ${#1} -gt 62 ] && return $MErr_APNLEN

        # Initial attach APN
    #    local apn="$1" 
    #    local tmp='AT+EIAAPN=\"apn_string\"'
    #    tmp=`echo "$tmp" | sed -e "s/apn_string/$apn/g"`

    #    ATCOMM $tmp
    #    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    #fi

    # option 2
    # Set full function
    #ATCOMM 'AT+CFUN?'
    #ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    #local status=`cat $gATLogFile | grep -w '+CFUN:' | cut -d' ' -f2`
    #[ -z "$status" ] && return $MErr_PCFUN
    
    #if [ $status -ne 1 ]; then
        #
        # Delay 4 seconds to wait for Pin status to ready
        #
    #    ATCOMM "AT+CFUN=1" 4
    #    local ret=$?
    #    if [ $ret -ne 0 ]; then
    #        return $ret
    #    fi
    #fi

    #return 0
#}

#Aiw357_iSetNormalModeForce()
#{
    # Set full function
#    ATCOMM 'AT+CFUN?'
#    ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
#    local status=`cat $gATLogFile | grep -w '+CFUN:' | cut -d' ' -f2`
#    [ -z "$status" ] && return $MErr_PCFUN

#    if [ $status -ne 1 ]; then
#        ATCOMM "AT+CFUN=1" $gAtCmdDelay
#        local ret=$?
#        if [ $ret -ne 0 ]; then
#            return $ret
#        fi
#    fi

#    return 0
#}

Aiw357_iConnect()
{
    Dbg3 "Aiw357_iConnect"
    
    ATCOMM 'AT+CGACT?' $gAtCmdDelay
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    local status=`cat $gATLogFile | grep -w '+CGACT:' | awk '{print $2}'`

    if [ -z "$status" ]; then
        ATCOMM 'AT+CGACT=1,0' $gAtCmdDelay
        ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
        status=`cat $gATLogFile | grep -w '+CGEV:' | awk '{print $2, $3, $4, $5}' | sed 's/ /_/g'`
        [ -z "$status" ] && return $MErr_PCONNECT
        Dbg3 "Connect ret: $status"
    fi

    #
    # Delay 3 seconds to Get IP address for reliable
    #
    ATCOMM 'AT+CGPADDR=0' 3 #$gAtCmdDelay
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    cat $gATLogFile | grep -w '+CGPADDR:' > /dev/null
    if [ $? -ne 0 ]; then
        return $MErr_PCONNECT
    fi

    return 0
}

Aiw357_iDisConnect()
{
    #
    # Option 1
    # Use AT+CGACT=0,0 to do the disconnnection, but the number of "ccnmi" will be changed
    #
    #ATCOMM 'AT+CGACT?' $gAtCmdDelay
    #local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    #local status=`cat $gATLogFile | grep -w '+CGACT:' | awk '{print $2}'`

    #if [ ! -z "$status" ]; then
    #    ATCOMM 'AT+CGACT=0,0' $gAtCmdDelay
    #    ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    #    status=`cat $gATLogFile | grep -w '+CGEV:' | awk '{print $2, $3, $4, $5}' | sed 's/ /_/g'`
    #    [ -z "$status" ] && return $MErr_PCONNECT
    #    Dbg3 "DisConnect ret: $status"
    #fi

    #return 0

    #
    # Option 2
    # Reset module to do the disconnnection
    # Minimal functionality, turn off radio and SIM power
    #
    ATCOMM 'AT+CFUN?'
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    local status=`cat $gATLogFile | grep -w '+CFUN:' | cut -d' ' -f2`
    [ -z "$status" ] && return $MErr_PCFUN

    #
    # Delay 4 seconds due to PCIe response
    #
    if [ $status -eq 1 ]; then
        ATCOMM "AT+CFUN=0" 4
        local ret=$?
        if [ $ret -ne 0 ]; then
            return $ret
        fi
    fi

    return 0
}

Aiw357_iGetDns()
{
    Dbg3 "Aiw357_iGetDns"
    
    ATCOMM 'AT+CGCONTRDP=0' $gAtCmdDelay
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    local primary_dns=`cat $gATLogFile | grep -w "+CGCONTRDP:" | cut -d',' -f6 | sed 's/\"//g' | grep -w "^[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*$"`
    local secondary_dns=`cat $gATLogFile | grep -w "+CGCONTRDP:" | cut -d',' -f7 | sed 's/\"//g' | grep -w "^[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*$"`
    [ -z "$primary_dns" ] && return $MErr_PDNS
    [ -z "$secondary_dns" ] && Msg "Not found the secondary DNS"

    Log_KeyToCmd "$KEY_PDNS" "$primary_dns" title
    [ ! -z "$secondary_dns" ] && Log_KeyToCmd "$KEY_SDNS" "$secondary_dns"

    return 0
}

#==============================================
#================ Command Set =================
#==============================================
Aiw357_Init()
{
    Dbg3 "Aiw357_$gRunCmd"
    Dbg3 "gAtCmdDelay: $gAtCmdDelay"

    local ret=`grep "^Aiw357_[^a-z].*" ${gModuleDir}/${gModuleName}/${gModuleName}.sh | cut -d'_' -f2 | sed 's/()//g' > $gModuleListFile`
    ret=$? && [ $ret -ne 0 ] && return $MErr_WRITELIST

    ProbeSerial 6 $gCfgPortSet $gCfgAtBaudrate
    ret=$? && [ $ret -ne 0 ] && gRetStr="Probe serial failed!" && return $ret

    Aiw357_l_WriteCfg "gDevNode=$gDevNode"
    ret=$? && [ $ret -ne 0 ] && return $MErr_WDEVNODE

    return 0
}

Aiw357_GetInfo()
{
    Dbg3 "Aiw357_$gRunCmd"

    ATCOMM "ATI"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    Log_ModuleCmd "[ATI]"
    cat $gATLogFile | grep -v 'ATI' | grep -v 'OK' >> $gATCmdDir/$gRunCmd.txt
    [ $? -ne 0 ] && return $MErr_WRITEINFO

    Log_ShowCmdResult

    return 0
}

Aiw357_GetSignal()
{
    Dbg3 "Aiw357_$gRunCmd"

    ATCOMM "AT+CSQ"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    local status=`cat $gATLogFile | grep "+CSQ:" | cut -d':' -f2 | sed 's/ //g'`
    [ -z "$status" ] && return $MErr_PSIGNAL
    Log_ModuleCmd "[+CSQ]: $status"
    # Extract RSSI
    status=`echo $status | cut -d',' -f1`
    Log_KeyToCmd "$KEY_RSSI" "$status" title 
    
    ATCOMM "AT+CESQ"
    ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    status=`cat $gATLogFile | grep "+CESQ:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PSIGNAL
    
    Log_ModuleCmd "[+CESQ]: $status" "append"
    Log_ShowCmdResult

    return 0
}

Aiw357_GetOperator()
{
    Dbg3 "Aiw357_$gRunCmd"

    ATCOMM "AT+COPS?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    local status=`cat $gATLogFile | grep "+COPS:" | cut -d':' -f2 | sed 's/^ //g' | sed 's/ /_/g'`
    [ -z $status ] && return $MErr_POPERATOR
    
    Log_ModuleCmd "[+COPS]: $status"
    Log_ShowCmdResult

    return 0
}

#
# Get the state of PS attachment
#
Aiw357_GetPSState()
{
    Dbg3 "Aiw357_$gRunCmd"

    ATCOMM "AT+CGATT?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    local status=`cat $gATLogFile | grep "+CGATT:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PPSSTATE
    
    Log_ModuleCmd "[+CGATT]: $status"
    Log_ShowCmdResult

    return 0
}

Aiw357_GetBand()
{
    Dbg3 "Aiw357_$gRunCmd"

    ATCOMM "AT+EPBSEH?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    Log_ModuleCmd "[+EPBSEH]:"
    cat $gATLogFile | grep -v 'OK' >> $gATCmdDir/$gRunCmd.txt
    [ $? -ne 0 ] && return $MErr_PBAND
    
    Log_ShowCmdResult
    
    return 0
}

#
# Get Radio Access Technology
#
Aiw357_GetRat()
{
    Dbg3 "Aiw357_$gRunCmd"

    ATCOMM "AT+ERAT?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    local status=`cat $gATLogFile | grep "+ERAT:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PRAT
    
    Log_ModuleCmd "[+ERAT]: $status"
    Log_ShowCmdResult

    return 0
}

#
# Get Current Cell Information
#
Aiw357_GetCellInfo()
{
    Dbg3 "Aiw357_$gRunCmd"

    ATCOMM "AT+EDMFAPP=6,4"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    Log_ModuleCmd "[AT+EDMFAPP]"
    cat $gATLogFile | grep -v 'OK' | grep -v "AT+EDMFAPP" >> $gATCmdDir/$gRunCmd.txt
    [ $? -ne 0 ] && return $MErr_PCELLINFO

    Log_ShowCmdResult

    return 0
}

Aiw357_GetApn()
{
    Dbg3 "Aiw357_$gRunCmd"

    if [ $gCfgUsbMode -ne $gCfgMbimUsbmode ]; then
        ATCOMM "AT+CGDCONT?"
        local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
        local status=`cat $gATLogFile | grep "CGDCONT:" | grep '"IP"' | cut -d',' -f3 | sed 's/\"//g'`
        [ -z $status ] && return $MErr_PAPN
    
        Log_ModuleCmd "[+CGDCONT]: $status"
        Log_KeyToCmd "$KEY_APN" "$status" title 
        Log_ShowCmdResult
    else
        Echo "APN: $gCfgApn"
    fi

    return 0
}

Aiw357_GetIP()
{
    Dbg3 "Aiw357_$gRunCmd"
    local ret;
    local mode;
    local status;

    #
    # USB mode with AIW-357
    # MBIM  mode: AT+EGMC=1,"usb_mode",1,1
    # RNDIS mode: AT+EGMC=1,"usb_mode",1,0
    # qurey     : AT+EGMC=0,"usb_mode"
    #
    if [ "$gCfgHwIface" = "$IFTYPE_USB" ]; then
        ATCOMM 'AT+EGMC=0,\"usb_mode\"'
        ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
        mode=`cat $gATLogFile | grep "+EGMC:" | cut -d' ' -f2 | cut -d',' -f3`
        [ -z "$mode" ] && return $MErr_PIPUSBMODE
    else
        mode=0
    fi

    #
    # Get IP with RNDIS
    #
    if [ "$mode" -eq 0 ]; then
        #
        # Delay 3 seconds to Get IP address for reliable
        #
        ATCOMM 'AT+CGPADDR=0' 3 #$gAtCmdDelay
        ret=$?
        if [ $ret -ne 0 ]; then
            status="0.0.0.0"
        else
            status=`cat $gATLogFile | grep "+CGPADDR:" | cut -d',' -f2 | sed 's/\"//g'`
            [ -z $status ] && return $MErr_PIP
        fi
    else
        # Not supported to get IP address in MBIM mode and it's aligned with 0.0.0.0
        status="0.0.0.0"
	ATCOMM 'AT+CGPADDR=0' 3 #$gAtCmdDelay
	status=`cat $gATLogFile | grep "+CGPADDR:" | cut -d',' -f2 | sed 's/\"//g'`
        [ -z $status ] && return $MErr_PIP

    fi

    Log_ModuleCmd "[+CGPADDR]: $status"
    Log_KeyToCmd "$KEY_IP" "$status" title 
    Log_ShowCmdResult

    return 0
}

#Aiw357_GetDns()
#{
#    Dbg3 "Aiw357_$gRunCmd"

#    ATCOMM 'AT+CGCONTRDP=0' $gAtCmdDelay
#    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
#    local primary_dns=`cat $gATLogFile | grep -w "+CGCONTRDP:" | cut -d',' -f6 | sed 's/\"//g' | grep -w "^[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*$"`
#    local secondary_dns=`cat $gATLogFile | grep -w "+CGCONTRDP:" | cut -d',' -f7 | sed 's/\"//g' | grep -w "^[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*$"`
#    [ -z "$primary_dns" ] && return $MErr_PDNS
#    [ -z "$secondary_dns" ] && Msg "Not found the secondary DNS"

#    Log_ModuleCmd "[+CGCONTRDP]: Primary DNS: $primary_dns, Secondary DNS: $secondary_dns"
#    Log_KeyToCmd "$KEY_PDNS" "$primary_dns" title
#    [ ! -z "$secondary_dns" ] && Log_KeyToCmd "$KEY_SDNS" "$secondary_dns"
#    Log_ShowCmdResult

#    return 0
#}

Aiw357_GetPin()
{
    Dbg3 "Aiw357_$gRunCmd"
    
    ATCOMM "AT+CPIN?" $gAtCmdDelay
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
   
    local status=`cat $gATLogFile | grep "CPIN:" | cut -d' ' -f2 | sed 's/\r//g'`
    [ -z $status ] && return $MErr_PPIN
    
    Log_ModuleCmd "[+CPIN]: $status"
    Log_KeyToCmd "$KEY_PIN" "$status" title 
    Log_ShowCmdResult

    return 0
}

Aiw357_GetPinLock()
{
    Dbg3 "Aiw357_$gRunCmd"
   
    ATCOMM 'AT+CLCK=\"SC\",2'
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret 
    
    local status=`cat $gATLogFile | grep "+CLCK:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PPINLOCK
    
    Log_ModuleCmd "[+CLCK]: $status"
    Log_ShowCmdResult
    
    return $status
}

#
# The below is alias to define USB mode
# MBIM:29 , RNDIS: 13
#
# AT command to get USB mode as below:
# MBIM  mode: AT+EGMC=1,"usb_mode",1,1
# RNDIS mode: AT+EGMC=1,"usb_mode",1,0
# qurey     : AT+EGMC=0,"usb_mode"
#
Aiw357_GetUsbMode()
{
    Dbg3 "Aiw357_$gRunCmd"
    local usbmode;

    if [ "$gCfgHwIface" = "$IFTYPE_PCI" ]; then
        Echo "This command is not supported to PCI interface"
        return 0
    fi    

    ATCOMM 'AT+EGMC=0,\"usb_mode\"'
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    local mode=`cat $gATLogFile | grep "+EGMC:" | cut -d' ' -f2 | cut -d',' -f3`
    [ -z "$mode" ] && return $MErr_PUSBMODE

    if [ "$mode" -eq 1 ]; then
        usbmode="29"
        Log_ModuleCmd "[+EGMC]: $usbmode (MBIM)"
    elif [ "$mode" -eq 0 ]; then
        usbmode="13"
        Log_ModuleCmd "[+EGMC]: $usbmode (RNDIS)"
    else
        return $MErr_USBMODEARG
    fi

    Log_KeyToCmd "$KEY_USBMODE" "$usbmode" title 
    Log_ShowCmdResult
    
    return 0
}

#
# Get registration status
#
Aiw357_GetRegStatus()
{
    Dbg3 "Aiw357_$gRunCmd"

    ATCOMM "AT+CREG?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    local status=`cat $gATLogFile | grep "+CREG:" | cut -d' ' -f 2`
    [ -z $status ] && return $MErr_PREGSTATUS
    
    Log_ModuleCmd "[+CREG]: $status"
    status=`echo $status | cut -d',' -f 2`
    
    #
    # The status is equal 4 that means the status is unknown and it's
    # relpaced to 0
    #
    if [ ! -z "$status" ] && [ $status -eq 4 ]; then
        status=0
    fi
    Log_KeyToCmd "$KEY_REGS" "$status" title
    Log_ShowCmdResult

    return 0
}

Aiw357_GetAuth()
{
    Dbg3 "Aiw357_$gRunCmd"

    ATCOMM "AT+CGAUTH?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    Log_ModuleCmd "[AT+CGAUTH?]"
    cat $gATLogFile | grep -v 'OK' | grep -v 'AT+CGAUTH?' >> $gATCmdDir/$gRunCmd.txt
    
    [ $? -ne 0 ] && return $MErr_AUTHINFO

    Log_ShowCmdResult
    
    return 0
}

Aiw357_GetCurrentMode()
{
    Dbg3 "Aiw357_$gRunCmd"

    ATCOMM "AT+CFUN?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    local status=`cat $gATLogFile | grep "+CFUN:" | cut -d' ' -f 2`
    [ -z $status ] && return $MErr_PCURMODE
    
    Log_ModuleCmd "[+CFUN?]: $status"
    status=`echo $status | cut -d',' -f 1 | sed 's/^ //g' | sed 's/\r//g'`

    local mode="Other"
    case $status in
        0)
        mode="Station-Off"
        ;;
        
        1)
        mode="Normal"
        ;;
        
        4)
        mode="AirPlane"
        ;;

        *)
        mode="Other($status)"
        ;;
    esac

    Log_KeyToCmd "$KEY_CURMODE" "$mode" title
    Log_ModuleCmd "$mode" "append"
    Log_ShowCmdResult

    return 0
}

Aiw357_GetImsi()
{
    Dbg3 "Aiw357_$gRunCmd"

    ATCOMM "AT+CIMI?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    local status=`cat $gATLogFile | grep "+CIMI:" | cut -d' ' -f2 | sed 's/^ //g'`
    [ -z $status ] && return $MErr_PIMSI

    Log_ModuleCmd "[+CIMI]: $status"
    Log_ShowCmdResult

    return 0
}

Aiw357_GetNetInterface()
{
    local iface;
    local ret;
    local status;

    if [ "$gCfgHwIface" = "$IFTYPE_PCI" ] && [ "$gCfgUsbMode" = "$gCfgRndisMode" ] ; then
        ATCOMM 'AT+EPDN=0,\"ifst\",16'
        ret=$? && [ $ret -ne 0 ] && return $MErr_GETIFFAIL
        status=`cat $gATLogFile | grep -w '+EPDN:' | grep -w 'new' | cut -d',' -f4 | sed "s/ //g" | tail -c 2`
        if [ -z "$status" ]; then
            status=`cat $gATLogFile | grep -w '+EPDN:' | grep -w 'update' | cut -d',' -f3 | sed "s/ //g" | tail -c 2`
        fi
        [ -z "$status" ] && return $MErr_PGETNETIF

        Common_iIsInteger $status
        if [ $? -eq 0 ]; then
            iface="ccmni$status"
            Dbg3 "bug The number of network interface is $iface"
        else
            return $MErr_PGETNETIF
        fi

        Log_ModuleCmd "[+EPDN]: $iface"
        Log_KeyToCmd "$KEY_NETIFACE" "$iface" title
        Log_ShowCmdResult
    else
        Echo "Only supported to RNDIS by PCIe"
    fi

    return 0
}

Aiw357_SetPin()
{
    Dbg3 "Aiw357_$gRunCmd: $@, \$\#: $#"

    # Help information with this command
    [ $# -le 0 ] && Aiw357_l_Help '<pin_string>' && return 0

    [ -z $1 ] && return $MErr_NULL
    [ ${#1} -gt 32 ] && return $MErr_PINLEN

    local pin="$1"
    local tmp='AT+CPIN=\"pin_string\"'
    tmp=`echo "$tmp" | sed -e "s/pin_string/$pin/g"`
    ATCOMM $tmp

    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    return 0
}

#Aiw357_InitRndis()
#{
#    Aiw357_iInitRndis "$1"
#    return $?
#}

Aiw357_SetApn()
{
    Dbg3 "Aiw357_$gRunCmd: $@"
    
    # Help information with this command
    [ $# -le 0 ] && Aiw357_l_Help '<apn_string>' && return 0

    if [ $gCfgUsbMode -ne $gCfgMbimUsbmode ]; then
        [ -z $1 ] && return $MErr_NULL
        [ ${#1} -gt 62 ] && return $MErr_APNLEN

        local apn="$1"
        local tmp='AT+CGDCONT=0,\"IP\",\"apn_string\"'
        tmp=`echo "$tmp" | sed -e "s/apn_string/$apn/g"`
    
        ATCOMM $tmp $gAtCmdDelay
        local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    else
        Dbg "Set APN: $gCfgApn"
    fi

    return 0
}


Aiw357_SetEIAApn()
{
    Dbg3 "Aiw357_$gRunCmd: $@"

    # Help information with this command
    [ $# -le 0 ] && Aiw357_l_Help '<apn_string>' && return 0

    if [ $gCfgUsbMode -eq $gCfgMbimUsbmode ]; then
        [ -z $1 ] && return $MErr_NULL
        [ ${#1} -gt 62 ] && return $MErr_APNLEN

        local apn="$1"
        local tmp='AT+EIAAPN=\"apn_string\"'
        tmp=`echo "$tmp" | sed -e "s/apn_string/$apn/g"`

        ATCOMM $tmp $gAtCmdDelay
        local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

        Dbg "Set EIAAPN: $gCfgApn"
    fi

    return 0
}


Aiw357_SetPinUnlock()
{
    Dbg3 "Aiw357_$gRunCmd: $@"
    
    # Help information with this command
    [ $# -le 0 ] && Aiw357_l_Help '<pin_code_string>' && return 0
    
    [ -z $1 ] && return $MErr_NULL
    [ ${#1} -gt 32 ]  &&  return $MErr_ULPINLEN
 
    local pin="$1"
    local tmp='AT+CLCK=\"SC\",0,\"pin_code\"'
    tmp=`echo "$tmp" | sed -e "s/pin_code/$pin/g"`

    ATCOMM $tmp
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    return 0
}

Aiw357_SetPinLock()
{
    Dbg3 "Aiw357_$gRunCmd: $@"

    # Help information with this command
    [ $# -le 0 ] && Aiw357_l_Help '<pin_code_string>' && return 0

    [ -z $1 ] && return $MErr_NULL
    [ ${#1} -gt 32 ]  &&  return $MErr_ULPINLEN

    local pin="$1"
    local tmp='AT+CLCK=\"SC\",1,\"pin_code\"'
    tmp=`echo "$tmp" | sed -e "s/pin_code/$pin/g"`

    ATCOMM $tmp
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    return 0
}

Aiw357_SetAuth()
{
    Dbg3 "Aiw357_$gRunCmd: $@"

    # Help information with this command
    [ $# -lt 3 ] && Aiw357_l_Help '<username_string> <password_string> <auth 0:None, 1:PAP, 2:CHAP>' && return 0

    if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
        return $MErr_NULL
    fi

    if [ ${#1} -gt 64 ] || [ ${#2} -gt 64 ]; then
        return $MErr_AUTHLEN
    fi

    if [ $3 -lt 0 ] || [ $3 -gt 2 ] 2> /dev/null; then
        return $MErr_AUTHTYPE
    fi

    local cid=0 
    local username="$1"
    local password="$2"
    local auth_type="$3"
    local tmp=''
    if [ "$username" != "0" ] &&  [ "$password" != "0" ]; then
        tmp='AT+CGAUTH=$cid,$auth_type,\"$username\",\"$password\"'
        tmp=`echo "$tmp" | sed -e "s/\\$cid/$cid/g"`
        tmp=`echo "$tmp" | sed -e "s/\\$auth_type/$auth_type/g"`
        tmp=`echo "$tmp" | sed -e "s/\\$username/$username/g"`
        tmp=`echo "$tmp" | sed -e "s/\\$password/$password/g"`
    else
        tmp="AT+CGAUTH=$cid"
    fi

    ATCOMM $tmp
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    return 0
}

Aiw357_SetNormalMode()
{
    # Set full function
    ATCOMM 'AT+CFUN?'
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    local status=`cat $gATLogFile | grep -w '+CFUN:' | cut -d' ' -f2`
    [ -z "$status" ] && return $MErr_PCFUN

    if [ $status -ne 1 ]; then
        Aiw357_l_ATCfunc 1 $1
        ret=$?
        return $ret
    fi

    return 0
}

Aiw357_SetAirPlaneMode()
{
    Aiw357_l_ATCfunc 4
    local ret=$?
    
    return $ret
}

Aiw357_SetStationOffMode()
{
    # Set station off mode
    ATCOMM 'AT+CFUN?'
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    local status=`cat $gATLogFile | grep -w '+CFUN:' | cut -d' ' -f2`
    [ -z "$status" ] && return $MErr_PCFUN

    if [ $status -ne 0 ]; then
        Aiw357_l_ATCfunc 0 $1
        ret=$?
        return $ret
    fi

    return 0
}

Aiw357_Reset()
{
    local ret;
    local pid;

    if [ "$gCfgHwIface" = "$IFTYPE_PCI" ]; then
        pid=`ps ax | grep -w "[m]bim-proxy" | sed 's/^[ \t]*//g' | cut -d' ' -f1`
        if [ ! -z "$pid" ]; then
            Dbg3 "To stop mbim-proxy with pid $pid"
            kill -9 $pid > /dev/null
            ret=$?
            if [ $ret -ne 0 ]; then
                return $MErr_PROXYFAIL
            fi
        fi
    fi

    Aiw357_l_ATCfunc 15
    ret=$?
   
    [ $ret -eq 0 ] && Msg "Please wait for $gCfgResetDelay seconds for module rebooting."

    return $ret
}

Aiw357_EnableMonitor()
{
    Dbg3 "Aiw357_$gRunCmd"
    
    Monitor_GetState
    local ret=$?
    if [ $ret -eq $M_RUN ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_MTRRUN)
        return $ret
    fi

    Monitor_Enable
    ret=$? && [ $ret -ne 0 ] && gRetStr=$(MErr_strCode2Msg $MErr_MTRENABLE) && return $ret
    
    return 0
}

Aiw357_DisableMonitor()
{
    Dbg3 "Aiw357_$gRunCmd"
    
    Monitor_GetCtrlState
    local ret=$?
    if [ $ret -ne $M_ENABLE ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_MTRDISABLE)
        return $ret
    fi

    Monitor_Disable
    ret=$? && [ $ret -ne 0 ] && gRetStr=$(MErr_strCode2Msg $MErr_MTRDISABLE) && return $ret  
    
    return 0
}

Aiw357_StopMonitor()
{
    Dbg3 "Aiw357_$gRunCmd"
    
    Monitor_GetState
    local ret=$?
    if [ $ret -eq $M_RUN ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_MTRSTOP)
        return $ret
    fi

    Monitor_Stop
    ret=$? && [ $ret -ne 0 ] && gRetStr=$(MErr_strCode2Msg $MErr_MTRSTOP) && return $ret
    
    return 0
}

Aiw357_GetMonitorState()
{
    Dbg3 "Aiw357_$gRunCmd"

    Monitor_GetCtrlState
    local ret=$?

    case $ret in
        $M_INIT)
        ctrl_s='Disable(Init)'
        ;;
        
        $M_ENABLE)
        ctrl_s='Enable'
        ;;
        
        $M_DISABLE)
        ctrl_s='Disable'
        ;;
        
        $M_STOP)
        ctrl_s='Stop'
        ;;
        
        *)
        ctrl_s="Unknow (Ctrl:$ret)"
        ;;
    esac

    Echo "$ctrl_s"
    #Echo "Control: $ctrl_s"
    #Echo "Monitor state: $monitor_state"
    
    return 0
}

Aiw357_SetLogLevel()
{
    Dbg3 "Aiw357_$gRunCmd"
    
    # Help information with this command
    [ $# -le 0 ] && Aiw357_l_Help "<$L_LEVEL0, $L_LEVEL1 or $L_LEVEL2>" && return 0
    
    if [ $1 -ne $L_LEVEL0 ] && [ $1 -ne $L_LEVEL1 ] && [ $1 -ne $L_LEVEL2 ]; then
        return $MErr_LOGARGUMENT
    fi

    Log_SetLogLevel $1
    local ret=$?
    if [ $ret -ne 0 ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_SETLOG)
        return $ret
    fi

    return 0
}

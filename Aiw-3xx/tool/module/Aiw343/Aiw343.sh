#!/bin/sh

. $gCommonDir/monitor_ctrl.sh
. $gCommonDir/module_err.sh
. $gCommonDir/qmi_wwan.sh

#
# This file is only used to AIW-343
#
gATLogFileFmt=$gATLogFile.fmt

#==============================================
#=============== Local function ===============
#==============================================
Aiw343_l_WriteCfg()
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

Aiw343_l_Help()
{
    echo "Usage: $0 $gRunCmd $@"
}

Aiw343_l_ATCfunc()
{
    Dbg3 "Aiw343_$gRunCmd"

    Monitor_GetState
    local ret=$?
    if [ $ret -eq $M_RUN ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_MTRRUN)
        return $ret
    fi

    ATCOMM "AT+CFUN=$1" "1"
    ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    return 0
}

#
# This function is used to remove some format of AT log
# after AT command done.
#
Aiw343_l_FmtAtLog()
{
    cat $gATLogFile | tr -d $'\r' | grep -v -e '^$' -e 'OK' -e 'AT+' > $gATLogFileFmt
    if [ $? -ne 0 ]; then
        return $?
    fi

    return 0
}

#==============================================
#================ API function ================
#==============================================
Aiw343_iCheckSim()
{
    #SIMPR: <mode>,<SIM>,<status>
    # <mode>    0: disabled, 1: enabled
    # <SIM>     0: local SIM, 1: remote SIM
    # <status>  0: SIM not inserted, 1: SIM inserted
    #SIMPR: 0,0,1
    #SIMPR: 0,1,0
    ATCOMM "AT+SIMPR?"
    local ret=$?
    if [ $ret -eq 0 ]; then
        return 0
    fi

    gRetStr="AT error!"
    return $ret
}



#==============================================
#================ Command Set =================
#==============================================
Aiw343_Init()
{
    Dbg3 "Aiw343_$gRunCmd"
    
    local ret=`grep "^Aiw343_[^a-z].*" ${gModuleDir}/${gModuleName}/${gModuleName}.sh | cut -d'_' -f2 | sed 's/()//g' > $gModuleListFile`
    ret=$? && [ $ret -ne 0 ] && return $MErr_WRITELIST

    ProbeSerial 6 $gCfgPortSet
    ret=$? && [ $ret -ne 0 ] && gRetStr="Probe serial failed!" && return $ret

    Aiw343_l_WriteCfg "gDevNode=$gDevNode"
    ret=$? && [ $ret -ne 0 ] && return $MErr_WDEVNODE

    return 0
}

Aiw343_GetInfo()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT+CGMM"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    Aiw343_l_FmtAtLog
    local status=`cat $gATLogFileFmt`
    [ $? -ne 0 ] && return $MErr_WRITEINFO
    Log_ModuleCmd "[+CGMM] $status"

    #ATCOMM "AT+CGMR"
    #local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    #Aiw343_l_FmtAtLog
    #local status=`cat $gATLogFileFmt`
    #[ $? -ne 0 ] && return $MErr_WRITEINFO
    #Log_ModuleCmd "[+CGMR] $status" "append"

    ATCOMM "AT+CGSN"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    Aiw343_l_FmtAtLog
    local status=`cat $gATLogFileFmt`
    [ $? -ne 0 ] && return $MErr_WRITEINFO
    Log_ModuleCmd "[+CGSN] $status" "append"

    ATCOMM "AT#SWPKGV"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    Aiw343_l_FmtAtLog
    Log_ModuleCmd "[#SWPKGV]" "append" 
    cat $gATLogFileFmt | grep -v 'OK' | grep -v 'AT#SWPKGV' >> $gATCmdDir/$gRunCmd.txt
    [ $? -ne 0 ] && return $MErr_WRITEINFO

    Log_ShowCmdResult

    return 0
}

Aiw343_GetSignal()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT+CSQ"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    local status=`cat $gATLogFile | grep "+CSQ:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PSIGNAL
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

Aiw343_GetOperator()
{
    Dbg3 "Aiw343_$gRunCmd"

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
Aiw343_GetPSState()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT+CGATT?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    local status=`cat $gATLogFile | grep "+CGATT:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PPSSTATE
    
    Log_ModuleCmd "[+CGATT]: $status"
    Log_ShowCmdResult

    return 0
}

Aiw343_GetBand()
{
    Dbg3 "Aiw343_$gRunCmd"

    #ATCOMM "AT+GTACT?"
    ATCOMM "AT#BND?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    local status=`cat $gATLogFile | grep "#BND:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PBAND
    
    Log_ModuleCmd "[#BND]: $status"
    Log_ShowCmdResult
    
    return 0
}

#
# Get Radio Access Technology
#
Aiw343_GetRat()
{
    Dbg3 "Aiw343_$gRunCmd"

    #ATCOMM "AT+GTRAT?"
    ATCOMM "AT+WS46?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    local status=`cat $gATLogFile | grep "+WS46:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PRAT
    
    Log_ModuleCmd "[+WS46]: $status"
    Log_ShowCmdResult

    return 0
}

#
# Get Current Cell Information
#
Aiw343_GetCellInfo()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT#SERVINFO"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    local status=`cat $gATLogFile | grep "#SERVINFO:" | cut -d':' -f2 | sed 's/^ //g' | sed 's/ /_/g'`
    [ -z $status ] && return $MErr_PCELLINFO

    Log_ModuleCmd "[#SERVINFO]: $status"
    Log_ShowCmdResult

    return 0
}

Aiw343_GetApn()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT+CGDCONT?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    local status=`cat $gATLogFile | grep "CGDCONT:" | grep '"IP"' | cut -d',' -f3 | sed 's/\"//g'`
    [ -z $status ] && return $MErr_PAPN
    
    Log_ModuleCmd "[+CGDCONT]: $status"
    Log_KeyToCmd "$KEY_APN" "$status" title 
    Log_ShowCmdResult

    return 0
}

Aiw343_GetIP()
{
    Dbg3 "Aiw343_$gRunCmd"

    #
    # Get IP with RmNet
    #
    ATCOMM "AT+CGPADDR=1"
    local ret=$?
    if [ $ret -eq 0 ]; then
        status=`cat $gATLogFile | grep "+CGPADDR:" | cut -d',' -f2 | sed 's/\"//g' | sed 's/\r//g'`
        [ -z $status ] && status="0.0.0.0"
    else
        status="0.0.0.0"
    fi

    Log_ModuleCmd "[+CGPADDR]: $status"
    Log_KeyToCmd "$KEY_IP" "$status" title
    Log_ShowCmdResult

    return 0
}

Aiw343_GetPin()
{
    Dbg3 "Aiw343_$gRunCmd"
    
    ATCOMM "AT+CPIN?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
   
    local status=`cat $gATLogFile | grep "CPIN:" | cut -d' ' -f2 | sed 's/\r//g'`
    [ -z $status ] && return $MErr_PPIN
    
    Log_ModuleCmd "[+CPIN]: $status"
    Log_KeyToCmd "$KEY_PIN" "$status" title 
    Log_ShowCmdResult

    return 0
}

Aiw343_GetPinCount()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT#PCT"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    local status=`cat $gATLogFile | grep "#PCT:" | cut -d' ' -f2 | sed 's/\r//g'`
    [ -z $status ] && return $MErr_PPINCNT

    Log_ModuleCmd "[#PCT]: $status"
    Log_ShowCmdResult

    return 0
}

Aiw343_GetPinLock()
{
    Dbg3 "Aiw343_$gRunCmd"
   
    ATCOMM 'AT+CLCK=\"SC\",2'
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret 
    
    local status=`cat $gATLogFile | grep "+CLCK:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PPINLOCK
    
    Log_ModuleCmd "[+CLCK]: $status"
    Log_ShowCmdResult
    
    return $status
}

#
# Get usbmode
#
Aiw343_GetUsbMode()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT#USBCFG?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    local status=`cat $gATLogFile | grep "#USBCFG:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PUSBMODE
    
    Log_ModuleCmd "[#USBCFG]: $status"
    Log_KeyToCmd "$KEY_USBMODE" "$status" title 
    Log_ShowCmdResult
    
    return 0
}

#
# Get registration status
#
Aiw343_GetRegStatus()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT+CEREG?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    local status=`cat $gATLogFile | grep "+CEREG:" | cut -d' ' -f 2`
    [ -z $status ] && return $MErr_PREGSTATUS
    
    Log_ModuleCmd "[+CEREG]: $status"
    status=`echo $status | cut -d',' -f 2`
    Log_KeyToCmd "$KEY_REGS" "$status" title 
    Log_ShowCmdResult

    return 0
}

Aiw343_GetAuth()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT#PDPAUTH?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    Log_ModuleCmd "[AT#PDPAUTH?]"
    cat $gATLogFile | grep -v 'OK' | grep -v 'AT#PDPAUTH?' >> $gATCmdDir/$gRunCmd.txt
    
    [ $? -ne 0 ] && return $MErr_AUTHINFO

    Log_ShowCmdResult
    
    return 0
}

Aiw343_GetCurrentMode()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT+CFUN?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    local status=`cat $gATLogFile | grep "+CFUN:" | cut -d' ' -f 2`
    [ -z $status ] && return $MErr_PCURMODE
    
    Log_ModuleCmd "[+CFUN?]: $status"
    status=`echo $status | sed 's/\r//g'`

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

Aiw343_GetImsi()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT+CIMI"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    Aiw343_l_FmtAtLog
    local status=`cat $gATLogFileFmt`
    [ -z $status ] && return $MErr_PIMSI

    Log_ModuleCmd "[+CIMI]: $status"
    Log_ShowCmdResult

    return 0
}

Aiw343_GetHotSwap()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT#HSEN?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    local status=`cat $gATLogFile | grep "#HSEN:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PHOTSWAP

    Log_ModuleCmd "[#HSEN]: $status"
    Log_ShowCmdResult

    return 0
}

Aiw343_SetPin()
{
    Dbg3 "Aiw343_$gRunCmd: $@, \$\#: $#"

    # Help information with this command
    [ $# -le 0 ] && Aiw343_l_Help '<pin_string>' && return 0

    [ -z $1 ] && return $MErr_NULL
    [ ${#1} -gt 32 ] && return $MErr_PINLEN

    local pin=$1
    ATCOMM "AT+CPIN=$pin"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    return 0
}

Aiw343_SetApn()
{
    Dbg3 "Aiw343_$gRunCmd: $@"
    
    # Help information with this command
    [ $# -le 0 ] && Aiw343_l_Help '<apn_string>' && return 0

    [ -z $1 ] && return $MErr_NULL
    [ ${#1} -gt 62 ] && return $MErr_APNLEN

    local apn="$1"
    local tmp='AT+CGDCONT=1,\"ip\",\"internet\"'
    tmp=`echo "$tmp" | sed -e "s/internet/$apn/g"`
    
    ATCOMM $tmp
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    return 0
}

Aiw343_SetPinUnlock()
{
    Dbg3 "Aiw343_$gRunCmd: $@"
    
    # Help information with this command
    [ $# -le 0 ] && Aiw343_l_Help '<pin_code_string>' && return 0
    
    [ -z $1 ] && return $MErr_NULL
    [ ${#1} -gt 32 ]  &&  return $MErr_ULPINLEN
 
    local pin="$1"
    local tmp='AT+CLCK=\"SC\",0,\"pin_code\"'
    tmp=`echo "$tmp" | sed -e "s/pin_code/$pin/g"`

    ATCOMM $tmp
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    return 0
}

Aiw343_SetPinLock()
{
    Dbg3 "Aiw343_$gRunCmd: $@"

    # Help information with this command
    [ $# -le 0 ] && Aiw343_l_Help '<pin_code_string>' && return 0

    [ -z $1 ] && return $MErr_NULL
    [ ${#1} -gt 32 ]  &&  return $MErr_ULPINLEN

    local pin="$1"
    local tmp='AT+CLCK=\"SC\",1,\"pin_code\"'
    tmp=`echo "$tmp" | sed -e "s/pin_code/$pin/g"`

    ATCOMM $tmp
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    return 0
}

Aiw343_SetAuth()
{
    Dbg3 "Aiw343_$gRunCmd: $@"

    # Help information with this command
    [ $# -lt 3 ] && Aiw343_l_Help '<username_string> <password_string> <auth 0:None, 1:PAP, 2:CHAP>' && return 0

    if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
        return $MErr_NULL
    fi

    if [ ${#1} -gt 64 ] || [ ${#2} -gt 64 ]; then
        return $MErr_AUTHLEN
    fi

    if [ $3 -lt 0 ] || [ $3 -gt 2 ] 2> /dev/null; then
        return $MErr_AUTHTYPE
    fi

    local cid=1
    local username="$1"
    local password="$2"
    local auth_type="$3"
    local tmp=''
    if [ "$username" != "0" ] &&  [ "$password" != "0" ]; then
        tmp='AT#PDPAUTH=$cid,$auth_type,\"$username\",\"$password\"'
        tmp=`echo "$tmp" | sed -e "s/\\$cid/$cid/g"`
        tmp=`echo "$tmp" | sed -e "s/\\$auth_type/$auth_type/g"`
        tmp=`echo "$tmp" | sed -e "s/\\$username/$username/g"`
        tmp=`echo "$tmp" | sed -e "s/\\$password/$password/g"`
    else
        tmp="AT#PDPAUTH=$cid,0"
    fi

    ATCOMM $tmp
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    return 0
}

Aiw343_SetNormalMode()
{
    Aiw343_l_ATCfunc 1
    local ret=$?
    
    return $ret
}

Aiw343_SetAirPlaneMode()
{
    Aiw343_l_ATCfunc 4
    local ret=$?
    
    return $ret
}

Aiw343_SetStationOffMode()
{
    Aiw343_l_ATCfunc 0
    local ret=$?
    
    return $ret
}

Aiw343_Reset()
{
    Aiw343_l_ATCfunc 6
    local ret=$?
   
    if [ $ret -eq 0 ]; then
        Msg "flush file with QMI WWAN network"
        Qmi_iFlush
        Msg "Please wait for $gCfgResetDelay seconds for module rebooting."
    fi

    return $ret
}

Aiw343_DisableHotSwap()
{
    Dbg3 "Aiw343_$gRunCmd"

    ATCOMM "AT#HSEN=0"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    return 0
}

Aiw343_SaveConfig()
{
    Dbg3 "Aiw343_$gRunCmd"

    # Store configuration
    ATCOMM "AT&W"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    return 0
}

Aiw343_EnableMonitor()
{
    Dbg3 "Aiw343_$gRunCmd"
    
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

Aiw343_DisableMonitor()
{
    Dbg3 "Aiw343_$gRunCmd"
    
    Monitor_GetState
    local ret=$?
    if [ $ret -eq $M_RUN ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_MTRRUN)
        return $ret
    fi

    Monitor_Disable
    ret=$? && [ $ret -ne 0 ] && gRetStr=$(MErr_strCode2Msg $MErr_MTRDISABLE) && return $ret  
    
    return 0
}

Aiw343_StopMonitor()
{
    Dbg3 "Aiw343_$gRunCmd"
    
    Monitor_GetState
    local ret=$?
    if [ $ret -eq $M_RUN ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_MTRRUN)
        return $ret
    fi

    Monitor_Stop
    ret=$? && [ $ret -ne 0 ] && gRetStr=$(MErr_strCode2Msg $MErr_MTRSTOP) && return $ret
    
    return 0
}

Aiw343_GetMonitorState()
{
    Dbg3 "Aiw343_$gRunCmd"

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
    
    return 0
}

Aiw343_SetLogLevel()
{
    Dbg3 "Aiw343_$gRunCmd"
    
    # Help information with this command
    [ $# -le 0 ] && Aiw343_l_Help "<$L_LEVEL0, $L_LEVEL1 or $L_LEVEL2>" && return 0
    
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

Aiw343_iSetUsbMode()
{
    [ -z $1 ] && return $MErr_NULL

    if [ $1 -ne 7 ] && [ $1 -ne 0 ]; then
        #Msg "Unsupported usbmode $1"
        return $MErr_USBMODEARG
    fi
    ATCOMM "AT#USBCFG=$1"
    local ret=$?
    if [ $ret -ne 0 ]; then
        #Msg "Set to usbmode failed."
        gRetStr="AT error!"
        return $ret
    fi

    return 0
}


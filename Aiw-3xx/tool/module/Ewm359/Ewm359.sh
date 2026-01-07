#!/bin/sh

. $gCommonDir/monitor_ctrl.sh
. $gCommonDir/module_err.sh

#==============================================
#=============== Local function ===============
#==============================================
Ewm359_l_WriteCfg()
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

Ewm359_l_Help()
{
    echo "Usage: $0 $gRunCmd $@"
}

Ewm359_l_ATCfunc()
{
    Dbg3 "Ewm359_$gRunCmd"

    Monitor_GetState
    local ret=$?
    if [ $ret -eq $M_RUN ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_MTRRUN)
        return $ret
    fi

    ATCOMM "AT+CFUN=$1" "2"
    ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    return 0
}

#==============================================
#================ API function ================
#==============================================
Ewm359_iCheckSim()
{
    return 0
}


#==============================================
#================ Command Set =================
#==============================================
Ewm359_Init()
{
    Dbg3 "Ewm359_$gRunCmd"
    
    local ret=`grep "^Ewm359_[^a-z].*" ${gModuleDir}/${gModuleName}/${gModuleName}.sh | cut -d'_' -f2 | sed 's/()//g' > $gModuleListFile`
    ret=$? && [ $ret -ne 0 ] && return $MErr_WRITELIST

    ProbeSerial 6 $gCfgPortSet
    ret=$? && [ $ret -ne 0 ] && gRetStr="Probe serial failed!" && return $ret

    Ewm359_l_WriteCfg "gDevNode=$gDevNode"
    ret=$? && [ $ret -ne 0 ] && return $MErr_WDEVNODE
    
    #
    # Enable access to password-protected
    #
    ATCOMM 'AT!ENTERCND=\"A710\"'
    ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    return 0
}

Ewm359_GetInfo()
{
    Dbg3 "Ewm359_$gRunCmd"

    ATCOMM "ATI"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    Log_ModuleCmd "[ATI]"
    cat $gATLogFile | grep ":" >> $gATCmdDir/$gRunCmd.txt
    [ $? -ne 0 ] && return $MErr_WRITEINFO

    Log_ShowCmdResult

    return 0
}

Ewm359_GetSignal()
{
    Dbg3 "Ewm359_$gRunCmd"

    ATCOMM "AT+CSQ"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    local status=`cat $gATLogFile | grep "+CSQ:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PSIGNAL
    Log_ModuleCmd "[+CSQ]: $status"
    # Extract RSSI
    status=`echo $status | cut -d',' -f1`
    Log_KeyToCmd "$KEY_RSSI" "$status" title 
    
    Log_ShowCmdResult

    return 0
}

Ewm359_GetOperator()
{
    Dbg3 "Ewm359_$gRunCmd"

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
Ewm359_GetPSState()
{
    Dbg3 "Ewm359_$gRunCmd"

    ATCOMM "AT+CGATT?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    local status=`cat $gATLogFile | grep "+CGATT:" | cut -d' ' -f2`
    [ -z $status ] && return $MErr_PPSSTATE
    
    Log_ModuleCmd "[+CGATT]: $status"
    Log_ShowCmdResult

    return 0
}

Ewm359_GetBand()
{
    Dbg3 "Ewm359_$gRunCmd"

    ATCOMM "AT!BAND?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
   
    Log_ModuleCmd "[!BAND]"
    cat $gATLogFile | grep -v 'OK' | grep -v 'BAND?' >> $gATCmdDir/$gRunCmd.txt
    [ $? -ne 0 ] && return $MErr_PBAND

    Log_ShowCmdResult
    
    return 0
}

#
# Get LTE Information
#
Ewm359_GetLteInfo()
{
    Dbg3 "Ewm359_$gRunCmd"

    ATCOMM "AT!LTEINFO?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    Log_ModuleCmd "[!LTEINFO?]"
    cat $gATLogFile | grep -v 'OK' | grep -v '!LTEINFO' >> $gATCmdDir/$gRunCmd.txt
    [ $? -ne 0 ] && return $MErr_LTEINFO

    Log_ShowCmdResult

    return 0
}

#
# Get status by EM9191 custom command
#
Ewm359_GetStatus()
{
    Dbg3 "Ewm359_$gRunCmd"

    ATCOMM "AT!GSTATUS?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    Log_ModuleCmd "[!GSTATUS?]"
    cat $gATLogFile | grep -v 'OK' | grep -v '!GSTATUS' >> $gATCmdDir/$gRunCmd.txt
    [ $? -ne 0 ] && return $MErr_STATUS

    Log_ShowCmdResult

    return 0
}

Ewm359_GetApn()
{
    Dbg3 "Ewm359_$gRunCmd"

    ATCOMM "AT+CGDCONT?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    local status=`cat $gATLogFile | grep "CGDCONT:" | grep '"IP"' | cut -d',' -f3 | sed 's/\"//g'`
    [ -z $status ] && return $MErr_PAPN
    
    Log_ModuleCmd "[+CGDCONT]: $status"
    Log_KeyToCmd "$KEY_APN" "$status" title 
    Log_ShowCmdResult

    return 0
}

Ewm359_GetIP()
{
    Dbg3 "Ewm359_$gRunCmd"

    #
    # Get IP with RmNet or MBIM mode 
    #
    ATCOMM "AT+CGPADDR"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    #
    # Get IP with MBIM mode only if not get IP above
    #
    ret=`cat $gATLogFile | grep '+CGPADDR:' | wc -l`
    if [ "$ret" -eq 3 ]; then
        status=`cat $gATLogFile | grep "+CGPADDR: 1" | cut -d',' -f2 | sed 's/\"//g' | sed 's/\r//g'`
        if [ "$status" = "0.0.0.0" ]; then
             status=`cat $gATLogFile | grep "+CGPADDR: 3" | cut -d',' -f2 | sed 's/\"//g' | sed 's/\r//g'`
        fi
    else
        status="0.0.0.0"
    fi
    [ -z $status ] && return $MErr_PIP
    
    Log_ModuleCmd "[+CGPADDR]: $status"
    Log_KeyToCmd "$KEY_IP" "$status" title 
    Log_ShowCmdResult

    return 0
}

Ewm359_GetPin()
{
    Dbg3 "Ewm359_$gRunCmd"
    
    ATCOMM "AT+CPIN?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
   
    local status=`cat $gATLogFile | grep "CPIN:" | cut -d' ' -f2 | sed 's/\r//g'`
    [ -z $status ] && return $MErr_PPIN
    
    Log_ModuleCmd "[+CPIN]: $status"
    Log_KeyToCmd "$KEY_PIN" "$status" title 
    Log_ShowCmdResult

    return 0
}

Ewm359_GetPinLock()
{
    Dbg3 "Ewm359_$gRunCmd"
   
    ATCOMM 'AT+CLCK=\"SC\",2'
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret 
    
    local status=`cat $gATLogFile | grep "+CLCK:" | cut -d' ' -f2 | sed 's/\r//g'`
    [ -z $status ] && return $MErr_PPINLOCK
    
    Log_ModuleCmd "[+CLCK]: $status"
    Log_KeyToCmd "$KEY_PINLOCK" "$status" title 
    Log_ShowCmdResult
    
    return $status
}

#
# Get registration status
#
Ewm359_GetRegStatus()
{
    Dbg3 "Ewm359_$gRunCmd"

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

Ewm359_GetAuth()
{
    Dbg3 "Ewm359_$gRunCmd"

    ATCOMM 'AT\$QCPDPP?'
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    Log_ModuleCmd '[AT$QCPDPP?]'
    cat $gATLogFile | grep -v 'OK' | grep -v '$QCPDPP?' >> $gATCmdDir/$gRunCmd.txt
    
    [ $? -ne 0 ] && return $MErr_AUTHINFO

    Log_ShowCmdResult
    
    return 0
}

Ewm359_GetCurrentMode()
{
    Dbg3 "Ewm359_$gRunCmd"
    local status;

    ATCOMM "AT+CFUN?"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    status=`cat $gATLogFile | grep "+CFUN:" | cut -d' ' -f2 | sed 's/\r//g'`
    [ -z $status ] && return $MErr_PCURMODE
    
    Log_ModuleCmd "[+CFUN?]: $status"

    local mode="Other"
    case $status in
        0)
        mode="Minimum Functionality"
        ;;
        
        1)
        mode="Full Functionality"
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

Ewm359_GetImsi()
{
    Dbg3 "Ewm359_$gRunCmd"

    ATCOMM "AT+CIMI"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    local status=`cat $gATLogFile | grep '[0-9]'`
    [ -z $status ] && return $MErr_PIMSI

    Log_ModuleCmd "[+CIMI]: $status"
    Log_ShowCmdResult

    return 0
}

Ewm359_SetPin()
{
    Dbg3 "Ewm359_$gRunCmd: $@, \$\#: $#"

    # Help information with this command
    [ $# -le 0 ] && Ewm359_l_Help '<pin_string>' && return 0

    [ -z $1 ] && return $MErr_NULL
    [ ${#1} -gt 32 ] && return $MErr_PINLEN

    local pin=$1
    ATCOMM "AT+CPIN=$pin"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    return 0
}

Ewm359_SetApn()
{
    Dbg3 "Ewm359_$gRunCmd: $@"
    
    # Help information with this command
    [ $# -le 0 ] && Ewm359_l_Help '<apn_string>' && return 0

    [ -z $1 ] && return $MErr_NULL
    [ ${#1} -gt 62 ] && return $MErr_APNLEN

    local apn="$1"
    local tmp='AT+CGDCONT=1,\"ip\",\"internet\"'
    tmp=`echo "$tmp" | sed -e "s/internet/$apn/g"`
    
    ATCOMM $tmp
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    return 0
}

Ewm359_SetPinUnlock()
{
    Dbg3 "Ewm359_$gRunCmd: $@"
    
    # Help information with this command
    [ $# -le 0 ] && Ewm359_l_Help '<pin_code_string>' && return 0
    
    [ -z $1 ] && return $MErr_NULL
    [ ${#1} -gt 32 ]  &&  return $MErr_ULPINLEN
 
    local pin="$1"
    local tmp='AT+CLCK=\"SC\",0,\"pin_code\"'
    tmp=`echo "$tmp" | sed -e "s/pin_code/$pin/g"`

    ATCOMM $tmp
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
    
    return 0
}

Ewm359_SetPinLock()
{
    Dbg3 "Ewm359_$gRunCmd: $@"

    # Help information with this command
    [ $# -le 0 ] && Ewm359_l_Help '<pin_code_string>' && return 0

    [ -z $1 ] && return $MErr_NULL
    [ ${#1} -gt 32 ]  &&  return $MErr_ULPINLEN

    local pin="$1"
    local tmp='AT+CLCK=\"SC\",1,\"pin_code\"'
    tmp=`echo "$tmp" | sed -e "s/pin_code/$pin/g"`

    ATCOMM $tmp
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    return 0
}

#Ewm359_SetAuth()
#{
#    Dbg3 "Ewm359_$gRunCmd: $@"

    # Help information with this command
#    [ $# -lt 3 ] && Ewm359_l_Help '<username_string> <password_string> <auth 0:None, 1:PAP, 2:CHAP, 3:PAP and CHAP>' && return 0

#    if [ -z $1 ] || [ -z $2 ] || [ -z $2 ]; then
#        return $MErr_NULL
#    fi

#    if [ ${#1} -gt 64 ] || [ ${#2} -gt 64 ]; then
#        return $MErr_AUTHLEN
#    fi

#    if [ $3 -lt 0 ] || [ $3 -gt 3 ] 2> /dev/null; then
#        return $MErr_AUTHTYPE
#    fi

    # Check cid
#    ATCOMM "AT+CGDCONT?"
#    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret
#    local cid=`cat $gATLogFile | grep "CGDCONT:" | grep '"IP"' | cut -d' ' -f2 | cut -d',' -f1 | sed 's/\"//g'`
#    if [ -z $cid ] || [ ! $cid -ge 0 ]; then
#        return $MErr_AUTHCID
#    fi
    
#    local username="$1"
#    local password="$2"
#    local auth_type="$3"
#    local tmp=''
#    if [ "$username" != "0" ] &&  [ "$password" != "0" ]; then
#        tmp='AT+MGAUTH=$cid,$auth_type,\"$username\",\"$password\"'
#        tmp=`echo "$tmp" | sed -e "s/\\$cid/$cid/g"`
#        tmp=`echo "$tmp" | sed -e "s/\\$auth_type/$auth_type/g"`
#        tmp=`echo "$tmp" | sed -e "s/\\$username/$username/g"`
#        tmp=`echo "$tmp" | sed -e "s/\\$password/$password/g"`
#    else
#        tmp="AT+MGAUTH=$cid"
#    fi

#    ATCOMM $tmp
#    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

#    return 0
#}

Ewm359_SetFullMode()
{
    Ewm359_l_ATCfunc 1
    local ret=$?
    
    return $ret
}

Ewm359_SetMiniMode()
{
    Ewm359_l_ATCfunc 0
    local ret=$?
    
    return $ret
}

Ewm359_Reset()
{
    ATCOMM "AT!RESET" "2"
    local ret=$? && [ $ret -ne 0 ] && gRetStr="AT error!" && return $ret

    [ $ret -eq 0 ] && Msg "Please wait for $gCfgResetDelay seconds for module rebooting."

    return $ret
}

#
# Get usbmode is fake command using by monitor.sh
# MBIM v2: 4
#
Ewm359_GetUsbMode()
{
    Dbg3 "Ewm359_$gRunCmd"

    Log_ModuleCmd "[Usbmode]: 4"
    Log_KeyToCmd "$KEY_USBMODE" "4" title
    Log_ShowCmdResult
    
    return 0
}

Ewm359_EnableMonitor()
{
    Dbg3 "Ewm359_$gRunCmd"
    
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

Ewm359_DisableMonitor()
{
    Dbg3 "Ewm359_$gRunCmd"
    
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

Ewm359_StopMonitor()
{
    Dbg3 "Ewm359_$gRunCmd"
    
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

Ewm359_GetMonitorState()
{
    Dbg3 "Ewm359_$gRunCmd"

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

    #Monitor_GetState
    #ret=$?
    #case $ret in
    #    $M_INIT)
    #    monitor_state='Init'
    #    ;;

    #    $M_RUN)
    #    monitor_state='Run'
    #    ;;

    #    $M_SLEEP)
    #    monitor_state='Sleep'
    #    ;;

    #    *)
    #    monitor_state="Unknow (Monitor state:$ret)"
    #    ;;
    #esac

    Echo "$ctrl_s"
    #Echo "Control: $ctrl_s"
    #Echo "Monitor state: $monitor_state"
    
    return 0
}

Ewm359_SetLogLevel()
{
    Dbg3 "Ewm359_$gRunCmd"
    
    # Help information with this command
    [ $# -le 0 ] && Ewm359_l_Help "<$L_LEVEL0, $L_LEVEL1 or $L_LEVEL2>" && return 0
    
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

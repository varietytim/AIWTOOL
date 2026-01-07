#!/bin/sh

. $gCommonDir/monitor_ctrl.sh
. $gCommonDir/command_err.sh

#
# To find the command list
#
gCmdListFile=/tmp/cmd.list

#==============================================
#=============== Local function ===============
#==============================================
Cmd_l_Help()
{
    echo "Usage: $0 $gRunCmd $@"
}

#==============================================
#================ Command Set =================
#==============================================
Cmd_Init()
{
    Dbg3 "Cmd_$gRunCmd"
    
    local ret=`grep "^Cmd_[^a-z].*" ${gCommonDir}/command.sh | cut -d'_' -f2 | sed 's/()//g' > $gCmdListFile`
    ret=$? && [ $ret -ne 0 ] && return $MErr_WRITELIST
    
    if [ ! -e $gWifiCmdDir ]; then
        mkdir -p $gWifiCmdDir    
	    ret=$? && [ $ret -ne 0 ] && return $MErr_MKCMDDIR
    fi

    return 0
}

Cmd_GetStatus()
{
	local iface=$1
	local ret;
	
    Dbg3 "Cmd_$gRunCmd"

    # Help information with this command
    [ $# -lt 1 ] && Cmd_l_Help "<wlan_interface> \n i.g. wlp1s0" && return 0

    if [ ! -e $gWifiCmdDir ]; then
        mkdir -p $gWifiCmdDir
        ret=$? && [ $ret -ne 0 ] && return $MErr_MKCMDDIR
    fi

    wpa_cli -i $iface status > $gWifiCmdDir/$gRunCmd.txt
    ret=$?
    if [ $ret -ne 0 ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_GETSTATUS)
        return $ret
    fi
   
    wpa_cli -i $iface signal_poll >> $gWifiCmdDir/$gRunCmd.txt
    ret=$?
    if [ $ret -ne 0 ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_SIGNALPOLL)
        return $ret
    fi

    cat $gWifiCmdDir/$gRunCmd.txt > $gWifiCmdDir/${gRunCmd}_kv.txt
    ret=$?
    if [ $ret -ne 0 ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_CAT)
        return $ret
    fi

    Log_ShowCmdResult

    return 0
}

Cmd_GetSnr()
{
    local iface=$1
    local bssid=$2
    local ret;

    Dbg3 "Cmd_$gRunCmd"

    # Help information with this command
    [ $# -lt 2 ] && Cmd_l_Help "<wlan_interface> <bssid>\n i.g. wlp1s0 74:fe:48:61:a4:76" && return 0

    if [ -z $1 ] || [ -z $2 ]; then
        return $MErr_NULL
    fi

    if [ ${#2} -ne 17 ]; then
        return $MErr_BSSID
    fi

    if [ ! -e $gWifiCmdDir ]; then
        mkdir -p $gWifiCmdDir
        ret=$? && [ $ret -ne 0 ] && return $MErr_MKCMDDIR
    fi

    wpa_cli -i $iface bss $bssid > $gWifiCmdDir/$gRunCmd.txt
    ret=$?
    if [ $ret -ne 0 ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_GETSNR)
        return $ret
    fi

    cat $gWifiCmdDir/$gRunCmd.txt > $gWifiCmdDir/${gRunCmd}_kv.txt
    ret=$?
    if [ $ret -ne 0 ]; then
        gRetStr=$(MErr_strCode2Msg $MErr_CAT)
        return $ret
    fi

    Log_ShowCmdResult

    return 0
}

Cmd_EnableMonitor()
{
    Dbg3 "Cmd_$gRunCmd"
    
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

Cmd_DisableMonitor()
{
    Dbg3 "Cmd_$gRunCmd"
    
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

Cmd_StopMonitor()
{
    Dbg3 "Cmd_$gRunCmd"
    
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

Cmd_GetMonitorState()
{
    Dbg3 "Cmd_$gRunCmd"

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

Cmd_SetLogLevel()
{
    Dbg3 "Cmd_$gRunCmd"
    
    # Help information with this command
    [ $# -le 0 ] && Cmd_l_Help "<$L_LEVEL0, $L_LEVEL1 or $L_LEVEL2>" && return 0
    
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

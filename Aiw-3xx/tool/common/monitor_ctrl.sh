#!/bin/sh

#
# Monitor state
#
M_INIT=0

# For control
M_ENABLE=1
M_DISABLE=2
M_STOP=4

# The states in while loop of monitor
M_RUN=3
M_SLEEP=5


#
# Global variables 
#
gMonitorCtrlFile=${gModuleDir}/monitor.ctrl
gMonitorStateFile=${gModuleDir}/monitor.state
gMonitorForRcLocalFile=/tmp/not_to_dialout_in_rclocal.txt

#====================================
#============ Functions =============
#====================================
Monitor_Init()
{
    if [ ! -e $gMonitorCtrlFile ]; then
        echo "$M_INIT" > $gMonitorCtrlFile
        local ret=$?
        [ $ret -ne 0 ] && return $ret
    fi

    if [ ! -e $gMonitorStateFile ]; then
        echo "$M_INIT" > $gMonitorStateFile
        ret=$?
        [ $ret -ne 0 ] && return $ret
    fi

    return 0
}

# Only used by tool
Monitor_Enable()
{
    Dbg3 "Monitor_Enable: $M_ENABLE"
    echo "$M_ENABLE" > $gMonitorCtrlFile
    local ret=$?
    FileDbg $gMonitorCtrlFile
    return $ret
}

# Only used by tool
Monitor_Disable()
{
    Dbg3 "Monitor_Disable: $M_DISABLE"
    echo "$M_DISABLE" > $gMonitorCtrlFile
    local ret=$?
    FileDbg $gMonitorCtrlFile
    return $ret
}

# Only used by tool
Monitor_Stop()
{
    Dbg3 "Monitor_Stop: $M_STOP"
    echo "$M_STOP" > $gMonitorCtrlFile
    local ret=$?
    FileDbg $gMonitorCtrlFile
    return $ret
}

# Only used by tool
Monitor_GetCtrlState()
{
    local ret=`cat $gMonitorCtrlFile`
    Dbg3 "Monitor_GetCtrlState ret:$ret"

    return $ret
}

# Only used by monitor.sh
Monitor_IsEnable()
{
    local ret=`cat $gMonitorCtrlFile`
    Dbg3 "Monitor_IsEnable ret:$ret"
    if [ $ret -eq $M_ENABLE ]; then
        return 0
    fi

    return 1
}

# Only used by monitor.sh
Monitor_IsStop()
{
    local ret=`cat $gMonitorCtrlFile`
    Dbg3 "Monitor_IsStop ret:$ret"
    if [ $ret -eq $M_STOP ]; then
        return 0
    fi

    return 1
}

# Only used by monitor.sh
Monitor_IsInit()
{
    local ret=`cat $gMonitorCtrlFile`
    Dbg3 "Monitor_IsInit ret:$ret"
    if [ $ret -eq $M_INIT ]; then
        return 0
    fi

    return 1
}

# Only used by monitor.sh
Monitor_SetState()
{
    echo "$1" > $gMonitorStateFile
    [ $? -eq 0 ] && return 0

    return 1
}

# Only used by tool
Monitor_GetState()
{
    local ret=`cat $gMonitorStateFile`
    return $ret
}

# Only used by setup.sh
Monitor_DisableBootDialForRclocal()
{
    touch $gMonitorForRcLocalFile
    [ $? -eq 0 ] && return 0

    return 1
}

#
# Check whether to dial out while rc.local restarted
#
# param[in] none.
#
# return  Dial out, zero is returned.
#         Don't dial out, one is returned.
#
# Only used by monitor.sh
Monitor_IsBootDialForRclocal()
{
    if [ -e $gMonitorForRcLocalFile ]; then
        return 1
    fi

    return 0
}

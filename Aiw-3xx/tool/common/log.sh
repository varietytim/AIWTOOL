#!/bin/sh

L_LEVEL0=0
L_LEVEL1=1
L_LEVEL2=2
gLogLevel=$L_LEVEL0

Log_Init()
{
    [ ! -e $gATCmdDir ] && mkdir -p $gATCmdDir    
    
    if [ ! -e $gLogLevelFile ]; then
        echo "$L_LEVEL0" > $gLogLevelFile
        gLogLevel=$L_LEVEL0
    else
        Log_GetLogLevel
        gLogLevel=$?
    fi

    return 0
}

LogDbg()
{
    [ $gDebug -ge 3 ] && Dbg "$1"
}

Log_ModuleCmd()
{
    local data="$1"

    if [ ! -z $2 ] && [ "$2" = "append" ]; then
        echo "$1" >> $gATCmdDir/$gRunCmd.txt
    else
        echo "$1" > $gATCmdDir/$gRunCmd.txt
    fi
}

Log_KeyValue()
{
    local data="$1"

    if [ ! -z $2 ] && [ "$2" = "append" ]; then
        echo "$1" >> $gATCmdDir/${gRunCmd}_kv.txt
    else
        echo "$1" > $gATCmdDir/${gRunCmd}_kv.txt
    fi
}

Log_KeyToCmd()
{
    local key="$1"
    local value="$2"

    if [ ! -z $3 ]; then
        # Add title
        Log_KeyValue "\n[more info]"
    fi

    local string=$(Log_FmtKeyVaule "$key" "$value")
    Log_KeyValue "$string" append
}

Log_FmtKeyVaule()
{
    local key="$1"
    local value="$2"

    echo "$key=$value"
}

Log_GetVaule()
{
    local key="$1"
    local value=`cat $gATCmdDir/${gRunCmd}_kv.txt | grep "$key" | cut -d'=' -f 2`
    echo "$value"
}

Log_ShowCmdResult()
{
    [ -e "$gATCmdDir/$gRunCmd.txt" ] && cat $gATCmdDir/$gRunCmd.txt
}

Log_AddTimeStamp()
{
    LogDbg "Log_AddTimeStamp loglevel: $gLogLevel"
    if [ $gLogLevel -ge $L_LEVEL1 ]; then
        echo "\n[$(date +%Y%m%d-%H%M%S)]" >> $gLogFile
    fi
}

Log_AddString()
{
    LogDbg "Log_AddState loglevel: $gLogLevel"
    if [ $gLogLevel -ge $L_LEVEL1 ]; then
        echo "$1" >> $gLogFile
    fi
}

Log_AddFile()
{
    LogDbg "Log_AddFile loglevel: $gLogLevel"
    if [ $gLogLevel -ge $L_LEVEL1 ]; then
        cat "$1" >> $gLogFile
    fi
}   

Log_AddCmdResult()
{
    LogDbg "Log_AddCmdResult loglevel: $gLogLevel"
    if [ $gLogLevel -ge $L_LEVEL1 ]; then
        cat $gATCmdDir/$gRunCmd.txt >> $gLogFile
    fi
}

# Only used by tool
Log_SetLogLevel()
{
    echo "$1" > $gLogLevelFile
    [ $? -eq 0 ] && return 0

    gLogLevel=$1

    return 1
}

# Only used by monitor.sh
Log_GetLogLevel()
{
    local ret=`cat $gLogLevelFile`
    if [ $ret -ge $L_LEVEL0 ] && [ $ret -le $L_LEVEL2 ]; then
        gLogLevel=$ret
    fi

    return $ret
}

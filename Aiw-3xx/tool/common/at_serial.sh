#!/bin/sh

gATLogFile=/tmp/module_at.log

if [ -e /dev/wwan0at0 ]; then
    gDevNode=/dev/wwan0at0
else	
    gDevNode=/dev/ttyUSB1
fi

gEnableLog=0
LOCKDIR=/var/lock/aiw_tool
LOCKFILE=/var/lock/aiw_tool/pid.lock
DEVUSE_FILE=/tmp/at_debug

#
# Init serial port for AT command
#
# param[in] $1: the string of a set of serial port.
#               ex: "/dev/ttyUSB1"
# param[in] $2: the baudrate.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
InitSerial()
{
    gDevNode=$1
    local Baudrate=9600
    local ret;

    if [ ! -z "$2" ]; then
        Baudrate="$2"
    fi

    ret=`stty -F $gDevNode speed $Baudrate -parenb -parodd -cmspar cs8 -hupcl -cstopb cread clocal -crtscts ignbrk -brkint -ignpar -parmrk -inpck -istrip -inlcr -igncr -icrnl -ixon -ixoff -iuclc -ixany -imaxbel -iutf8 -opost -olcuc -ocrnl -onlcr -onocr -onlret -ofill -ofdel nl0 cr0 tab0 bs0 vt0 ff0 -isig -icanon -iexten -echo -echoe -echok -echonl -noflsh -xcase -tostop -echoprt -echoctl -echoke -flusho -extproc 2> /dev/null`

    if [ "$ret" = "$Baudrate" ]; then
        Dbg "Set baudrate to $Baudrate with $gDevNode successful."
        return 0
    else
        Dbg "Set baudrate to $Baudrate with $gDevNode failed."
        return $MErr_ATBAUDRATE
    fi
}

AT_EnableLog()
{   
    gEnableLog=1
    return 0
}

AT_DisableLog()
{   
    gEnableLog=0
    return 0
}

#
# Check the device nodes whether using by application or not
#
# param[in] $1: the string of a set of serial port.
#               ex: "/dev/ttyUSB1:/dev/ttyUSB2"
#
# return  Device is using by application, zero is returned.
#         Device isn't using by application, others.
#
AT_IsDevUse()
{
    local comport_set=$1
    local total=0
    local ret;
    local port;
    local i;
    
    #
    # Check the set of ports is not null and get the nubmer of ports
    #
    [ -z $comport_set ] && return $MErr_ATARG
    local end=`echo "$comport_set" | awk '{print gsub(/:/, "")}'`
    
    #
    # This is for debug used by vendor tool
    #
    [ -e $DEVUSE_FILE ] && return $MErr_ATDEVFREE

    #
    # The loop to check devices
    #
    end=$((end + 1))
    for i in $(seq 1 $end)
    do
        port=`echo $comport_set | cut -d: -f$i`
        if [ ! -z $port ]; then
            Dbg2 "[$i] $port"
            i=$((i + 1))
            total=$((total + 1))

            lsof "$port" > /dev/null 2>&1
            ret=$?
            [ $ret -eq 0 ] && return 0
        else
            break
        fi
    done

    Dbg "total device: $total"

    return $MErr_ATDEVFREE
}

#
# Check the device nodes exist or not
#
# param[in] $1: the string of a set of serial port.
#               ex: "/dev/ttyUSB1:/dev/ttyUSB2"
#
# return  Device exist, zero is returned.
#         Device not exist, others.
#
AT_IsDevExist()
{
    local comport_set=$1
    local total=0
    local port;
    local i;

    #
    # Check the set of ports is not null and get the nubmer of ports
    #    
    [ -z $comport_set ] && return $MErr_ATARG
    local end=`echo "$comport_set" | awk '{print gsub(/:/, "")}'`

    #
    # The loop to check devices
    #
    end=$((end + 1))    
    for i in $(seq 1 $end)
    do
        port=`echo $comport_set | cut -d: -f$i`
        if [ ! -z $port ]; then
            Dbg2 "[$i] $port"
            i=$((i + 1))
            total=$((total + 1))

            [ ! -e $port ] && return $MErr_ATNODEV
        else
            break
        fi
    done

    Dbg "total device: $total"

    return 0
}

AT_Lock()
{
    local lockdir="$LOCKDIR"
    local pidfile="$LOCKFILE"
    
    if ( mkdir ${lockdir} ) 2> /dev/null; then
        echo $$ > $pidfile
        trap '' INT
        trap 'rm -rf "$lockdir"' EXIT
        return 0
    fi

    return 1
}

AT_UnLock()
{
    local lockdir="$LOCKDIR"
    
    rm -rf "$lockdir"
    trap - INT TERM EXIT
    
    return 0
}

ATCOMM()
{
    local device=$gDevNode;
    local ATcommand=$1;
    local cmd_delay=$2;
    local dbg_level=0
    local ret=1
    local cmd="none"

    if [ -e $gATLogFile ]; then
        rm $gATLogFile
    fi 
    #
    # Check node exist or not
    #
    if [ ! -e $device ]; then
        return $MErr_ATNODEV
    fi

    #===================================#
    #   Get into critical section
    #===================================#
    AT_Lock
    ret=$? && [ $ret -ne 0 ] && return $MErr_ATLOCKFAIL

    #
    # Send command to module
    #
    Dbg "at-cmd: $ATcommand"
    sh -c "printf \"$ATcommand\r\n\" > $device" && cat $device > $gATLogFile &
    local cat_pid=$!
    Dbg "cat-pid: <$cat_pid>"

    #
    # Waiting for module's response
    #
    if [ ! -z $cmd_delay ] && [ $cmd_delay -lt 10 ]; then
        sleep $cmd_delay
    else
        sleep 0.5
    fi
    FileDbg $gATLogFile
        
    #
    # Disconnect with cat session
    #
    ps $cat_pid > /dev/null
    if [ $? -eq 0 ]; then
        kill -15 $cat_pid
    else
        AT_UnLock
        if [ -e $device ]; then
            return $MErr_ATNOPID
        fi
    fi 

    #
    # Add AT command to log if needed
    # 
    [ $gEnableLog ] && [ $gLogLevel -ge $L_LEVEL2 ] && Log_AddFile "$gATLogFile"

    #
    # Parser response is OK or not
    #

    if [ -e $gATLogFile ]; then
        cmd=`cat $gATLogFile | grep "$ATcommand" | wc -l`
        ret=`cat $gATLogFile | grep "OK"`
        Dbg "cmd: $cmd ret: $ret"

        if [ $cmd -ge 0 ] && [ ! -z "$ret" ]; then
            AT_UnLock
            Dbg "At command executed successful!"
            return 0
        fi
    fi

    AT_UnLock
    Dbg "At command executed error!"
    return $MErr_ATEXECCMD
    
    #===================================#
    #      Exit critical section
    #===================================#
}

#
# Probe the device whether ready to receive AT command
#
# param[in] $1: the number of retry
#           $2: the string of a set of serial port.
#               ex: "3:/dev/ttyUSB1:/dev/ttyUSB2"
# param[in] $3: the baudrate.
#
# return  Device exist, zero is returned.
#         Device not exist, others.
#
ProbeSerial()
{
    Dbg3 "ProbeSerial"
    local retry=$1
    local ports=$2
    local baudrate=$3
    local ret;
    local mod;
    local port;
    
    if [ -e $gATLogFile ]; then
        rm $gATLogFile   
    fi

    #
    # Parser ports to get the number of total com port
    #
    local total_port=`echo $ports | cut -d: -f1`
    local probe_cnt=`expr $retry \* $total_port`
    Dbg2 "retry=$retry, probe_cnt=$probe_cnt, total_port=$total_port"

    #
    # Start to probe the com port
    #
    local ii=0
    while :
    do
        local mod=`expr $ii % $total_port`
        mod=$((mod + 2))
        port=`echo $ports | cut -d: -f$mod`
        Dbg2 "current port to probe is $port"

        InitSerial $port $baudrate
        ret=$?
        ii=$((ii+1))

        if [ $ret -ne 0 ] && [ $ii -lt $probe_cnt ]; then
            sleep 0.5
            continue
        fi

	AT_UnLock 

        ATCOMM "AT"
        if [ $? -eq 0 ]; then
            Dbg "[serial] DevNode is $gDevNode"
            break
        fi

        if [ $ii -ge $probe_cnt ]; then
            return $MErr_ATPROBE
        fi

        sleep 0.5
    done

    return 0
}

AT_LogToFile()
{
    local filepath=$1

    if [ ! -z $filepath ]; then
        cat $gATLogFile > $filepath
    fi

    return 0
}


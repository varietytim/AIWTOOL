#!/bin/sh

#
# The argument we expected is action and write the value
# back to variable from user input after parsered.
#
# param[in] $1: the string of argument.
# param[in] $2: the string of action.
# param[in] $3: the string of name of variable.
# param[in] $4: the value that we want to write back to variable from user input.
# param[in] $5: the string of debug message.
#
# i.g. Arg_Action "stop" "stop" "var_flag" "5" "Enable stop flag"
#      After parsered, you will get result as "var_flag=5"
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Arg_Action()
{
    local arg="$1"
    local action="$2"
    local varname="$3"
    local value="$4"
    local msg="$5"

    if [ -z "$arg" ] || [ -z "$action" ] || [ -z "$varname" ] || [ -z "$value" ]; then
        return 1
    fi
   
    if [ "$arg" = "$action" ]; then
        eval "$varname"="$value"
        [ ! -z "$msg" ] && Dbg "$msg"
        return 0
    fi

    return 2
}

#
# action is "stop"
#
Arg_Stop()
{
    local arg="$1"
    local varname="$2"
    local value="$3"

    if [ -z "$arg" ] || [ -z "$varname" ] || [ -z "$value" ]; then
        return 1
    fi

    Arg_Action "$arg" "stop" "$varname" "$value" "Stopping ..." 

    return $?
}

#
# action is "netif"
#
Arg_NetIface()
{
    local arg="$1"
    local varname="$2"
    local value="$3"

    if [ -z "$arg" ] || [ -z "$varname" ] || [ -z "$value" ]; then
        return 1
    fi

    Arg_Action "$arg" "netif" "$varname" "$value" "Update network interface."

    return $?
}

#
# The argument we expected is number and write the value
# back to variable from user input after parsered.
#
# param[in] $1: the string of argument.
# param[in] $2: the string of name of variable.
# param[in] $3: the string of key.
# param[in] $4: the string of debug message. 
#
# i.g. Arg_ValueIsNumber "time=123" "var_time" "time" "This is time"
#      After parsered, you will get result as "var_time=123"
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Arg_ValueIsNumber()
{
    local arg="$1"
    local varname="$2"
    local key="$3"
    local msg="$4"
    local num=''

    if [ -z "$arg" ] || [ -z "$varname" ] || [ -z "$key" ]; then
        return 1
    fi

    num=`echo "$arg" | grep "$key" | cut -d'=' -f2`
    if [ ! -z $num ] && [ $num -ge 1 ] 2> /dev/null; then
        eval "$varname"="$num"
        [ ! -z "$msg" ] && eval Dbg "\"$msg \$$varname\""
        return 0
    fi

    return 1
}

#
# regcnt=<retry_reg_cnt>
# regcnt=50
#
Arg_KvRegCnt()
{
    local arg="$1"
    local varname="$2"

    if [ -z "$arg" ] || [ -z "$varname" ]; then
        return 1
    fi

    Arg_ValueIsNumber "$arg" "$varname" "regcnt" "Reg retry count:"

    return $?
}

#
# delay=<delay_time>
# delay=50
#
Arg_KvDelayTime()
{
    local arg="$1"
    local varname="$2"

    if [ -z "$arg" ] || [ -z "$varname" ]; then
        return 1
    fi

    Arg_ValueIsNumber "$arg" "$varname" "delay" "Delay time:"

    return $?
}

#!/bin/sh

CErr_Init()
{
    local i=0
    local name=''
    local msg=''
    local code=''

    set -- \
    "0" "CErr_OK"               "OK" \
    "201" "CErr_NULL"           "Argument is null." \
    "202" "CErr_INVALID"        "Invalid argument." \
    "203" "CErr_SUPPLICANT"     "Start to run wpa_supplicant failed." \
    "204" "CErr_SETROAM"        "Setting with roaming failed." \
    "205" "CErr_REASSOCIATE"    "Reassociate with roaming failed." \
    "206" "CErr_NOINF"          "Not found the WiFi interface." \
    "207" "CErr_STOPSUPPLICANT" "To stop wpa_supplicant failed." \
    "208" "CErr_RECORDSSID"     "To record SSID failed." \

    end=`expr $# / 3`

    for i in $(seq 1 $end)
    do
        i=`expr $i \* 3`
        eval code=\${$((i - 2))}
        eval name=\${$((i - 1))}
        eval msg=\${$i}
        #Dbg "[$i] $name:$code:$msg"
        eval "$name"="$code"
        #eval "$name"="\"$code\""
        eval "CErr_${code}"="\"$msg\""
    done

    return 0
}

CErr_strCode2Msg()
{
    eval "echo \$CErr_${1}"
}

#CErr_Init
#mstr=$(CErr_strCode2Msg $1)
#echo "return errstr: $mstr"


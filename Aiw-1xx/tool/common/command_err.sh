#!/bin/sh

MErr_Init()
{
    local i=0
    local name=''
    local msg=''
    local code=''

    set -- \
    "0" "MErr_OK"          "OK" \
    "100" "MErr_Start"       "The first number of command error!" \
    "101" "MErr_NULL"        "Argument is null!" \
    "102" "MErr_INVALID"     "Invalid argument!" \
    "103" "MErr_WRITELIST"   "Write the list failed!" \
    "104" "MErr_WRITEINFO"   "Write the information failed!" \
    "105" "MErr_WRITECFG"    "Write the config failed!" \
    "106" "MErr_WDEVNODE"    "Write the device node to config failed!" \
    "122" "MErr_LOGARGUMENT" "Invalid argument passed to 'SetLogLevel'!" \
    "123" "MErr_SETLOG"      "Error code from 'SetLogLevel'." \
    "124" "MErr_MTRRUN"      "Monitor is running, please wait a moment and retry again." \
    "125" "MErr_MTRDISABLE"  "Disable monitor failed!" \
    "126" "MErr_MTRSTOP"     "Stop monitor failed!" \
    "127" "MErr_MTRENABLE"   "Enable monitor failed!" \
    "128" "MErr_MKCMDDIR"    "Create the directory of command failed!" \
    "129" "MErr_GETSTATUS"   "Get status failed!" \
    "130" "MErr_CAT"    	 "Cat to file failed!" \
    "131" "MErr_SIGNALPOLL"  "Signal polling failed!" \
    "132" "MErr_GETSNR"    	 "Get SNR failed!" \
    "133" "MErr_BSSID"       "The format or length of BSSID is incorrect" \
    "199" "MErr_End"         "The last number of module error!" \

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
        eval "MErr_${code}"="\"$msg\""
    done

    return 0
}

MErr_strCode2Msg()
{
    eval "echo \$MErr_${1}"
}

#MErr_Init
#mstr=$(MErr_strCode2Msg $1)
#echo "return errstr: $mstr"


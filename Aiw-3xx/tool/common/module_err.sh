#!/bin/sh

MErr_Init()
{
    local i=0
    local name=''
    local msg=''
    local code=''

    set -- \
    "0" "MErr_OK"          "OK" \
    "100" "MErr_Start"       "The first number of module error!" \
    "101" "MErr_NULL"        "Argument is null!" \
    "102" "MErr_INVALID"     "Invalid argument!" \
    "103" "MErr_WRITELIST"   "Write the list failed!" \
    "104" "MErr_WRITEINFO"   "Write the information failed!" \
    "105" "MErr_WRITECFG"    "Write the config failed!" \
    "106" "MErr_WDEVNODE"    "Write the device node to config failed!" \
    "107" "MErr_PSIGNAL"     "Parser null with CSQ or CESQ!" \
    "108" "MErr_POPERATOR"   "Parser null with COPS!" \
    "109" "MErr_PPSSTATE"    "Parser null with CGATT!" \
    "110" "MErr_PBAND"       "Parser null with GTACT!" \
    "111" "MErr_PRAT"        "Parser null with GTRAT!" \
    "112" "MErr_PCELLINFO"   "Parser null with GTCCINFO!" \
    "113" "MErr_PAPN"        "Parser null with CGDCONT!" \
    "114" "MErr_PIP"         "Parser null with CGDCONT!" \
    "115" "MErr_PPIN"        "Parser null with CPIN!" \
    "116" "MErr_PPINLOCK"    "Parser null with CLCK!" \
    "117" "MErr_PUSBMODE"    "Parser null with USB mode!" \
    "118" "MErr_PREGSTATUS"  "Parser null with CEREG!" \
    "119" "MErr_PINLEN"      "The maximum length of pin code is 32!" \
    "120" "MErr_ULPINLEN"    "The maximum length of pin code is 32!" \
    "121" "MErr_APNLEN"      "The maximum length of APN is 62!" \
    "122" "MErr_LOGARGUMENT" "Invalid argument passed to 'SetLogLevel'!" \
    "123" "MErr_SETLOG"      "Error code from 'SetLogLevel'." \
    "124" "MErr_MTRRUN"      "Monitor is running, please wait a moment and retry again." \
    "125" "MErr_MTRDISABLE"  "Disable monitor failed!" \
    "126" "MErr_MTRSTOP"     "Stop monitor failed!" \
    "127" "MErr_MTRENABLE"   "Enable monitor failed!" \
    "128" "MErr_USBMODEARG"  "Unsupported usbomode!" \
    "129" "MErr_AUTHINFO"    "Get authentication information failed!" \
    "130" "MErr_AUTHLEN"     "The maximum length of authentication is 64!" \
    "131" "MErr_AUTHCID"     "Get cid failed!" \
    "132" "MErr_AUTHTYPE"    "Input authentication type is undefined!" \
    "133" "MErr_NOMODULE"    "Not found the module!" \
    "134" "MErr_PIPUSBMODE"  "Parser null with USB mode for get IP!" \
    "135" "MErr_RMCALL"      "No connection established!" \
    "136" "MErr_PCURMODE"    "Parser null with CFUN!" \
    "137" "MErr_PIMSI"       "Parser null with CIMI!" \
    "138" "MErr_LTEINFO"     "Get LTE information failed!" \
    "139" "MErr_STATUS"      "Get status failed!" \
    "140" "MErr_ATBAUDRATE"  "Set baudrate failed!" \
    "141" "MErr_ATEXECCMD"   "AT command executed error!" \
    "142" "MErr_ATPROBE"     "AT probe failed!" \
    "143" "MErr_ATNODEV"     "Device node is not exist!" \
    "144" "MErr_ATDEVFREE"   "Device node is free" \
    "145" "MErr_ATNOPID"     "Not found the PID with AT command!" \
    "146" "MErr_ATLOCKFAIL"  "AT lock failed!" \
    "147" "MErr_ATARG"       "Argument is null!" \
    "148" "MErr_PPINCNT"     "Parser null with #PCT!" \
    "149" "MErr_PHOTSWAP"    "Parser null with hot swap enable!" \
    "150" "MErr_NOCARRIES"   "No carrier!" \
    "151" "MErr_PDNS"        "Parser null with DNS!" \
    "152" "MErr_PCFUN"       "Parser null with AT command CFUN!" \
    "153" "MErr_PCONNECT"    "Parser null with AT command CGACT or CGPADDR!" \
    "154" "MErr_PGETNETIF"   "Parser null to get network interface!" \
    "155" "MErr_GETIFFAIL"   "Please create the connection first!" \
    "156" "MErr_PROXYFAIL"   "Stop mbim-proxy failed!" \
    "157" "MErr_End"         "The last number of module error!" \

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


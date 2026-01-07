#!/bin/sh

DErr_Init()
{
    local i=0
    local name=''
    local msg=''
    local code=''

    set -- \
    "0" "DErr_OK"               "OK" \
    "201" "DErr_NULL"           "Argument is null!" \
    "202" "DErr_INVALID"        "Invalid argument!" \
    "203" "DErr_PIN"            "Pin code is not ready!" \
    "204" "DErr_UNKNOWMODE"     "Unknow USB mode!" \
    "205" "DErr_SETMODE"        "Set usbmode failed!" \
    "206" "DErr_SETAPN"         "Set APN failed!" \
    "207" "DErr_SETAUTH"        "Authentication setting failed!" \
    "208" "DErr_PINUNLOCK"      "Unlock pin code failed!" \
    "209" "DErr_SETPIN"         "Set pin code failed!" \
    "210" "DErr_GNCONNECT"      "Connecting failed for GobiNet!" \
    "211" "DErr_GNDISCONNECT"   "Disconnect failed for GobiNet!" \
    "212" "DErr_MBDISCONNECT"   "Disconnect failed for MBIM!" \
    "213" "DErr_REG"            "Registration failed!" \
    "214" "DErr_REGNULL"        "Parser null with registration process!" \
    "215" "DErr_PINNULL"        "Parser null with pin status!" \
    "216" "DErr_NOPINCFG"       "PIN status is not ready." \
    "217" "DErr_NOCFG"          "Please run the setup.sh firstly." \
    "218" "DErr_NOMDEV"         "Not found the device node (/dev/cdc-wdmX)!" \
    "219" "DErr_DEVUSE"         "The device node of ttyUSBx is used by other process." \
    "220" "DErr_LOADGBDRV"      "Load the driver of GobiNet is failed." \
    "221" "DErr_LOADMBIMDRV"    "Load the driver of MBIM is failed." \
    "222" "DErr_PERMDENIED"     "No root permission." \
    "223" "DErr_NOMODELNAME"    "Not find the model name in configuration!" \
    "224" "DErr_PPINLOCK"       "Parser null with pin code lock." \
    "225" "DErr_SETPINBYUSER"   "Set pin code failed, please to set pin code manually" \
    "226" "DErr_LOADQMIDRV"     "Load the driver of QMI WWAN is failed." \
    "227" "DErr_LOADPCIDRV"     "Load PCI driver failed." \

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
        eval "DErr_${code}"="\"$msg\""
    done

    return 0
}

DErr_strCode2Msg()
{
    eval "echo \$DErr_${1}"
}

#DErr_Init
#mstr=$(DErr_strCode2Msg $1)
#echo "return errstr: $mstr"


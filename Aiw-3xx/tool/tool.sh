#============================================================================
# AIW tool script
#============================================================================
#!/bin/sh

#
# Work folders
#
gWorkdir=$(dirname $(readlink -f $0))
gTopdir=$(dirname $gWorkdir)
gCommonDir=${gWorkdir}/common

#
# Golobal variables
#
. $gCommonDir/common_var.sh
. $gCommonDir/module_var.sh

#
# Import modules
#
. $gCommonDir/common.sh
. $gCommonDir/debug.sh
. $gCommonDir/at_serial.sh
. $gCommonDir/log.sh
. $gCommonDir/parser.sh
. $gCommonDir/module_err.sh
. $gCommonDir/monitor_ctrl.sh

#
# The current command
#
gRunCmd="none"

Tool_LoadDriver()
{
    modprobe option
    Dbg "modprobe option"
    sleep 0.1
    if [ ! -z $gCfgVendorId ] && [ ! -z $gCfgProductId ]; then
        sh -c "echo $gCfgVendorId $gCfgProductId > /sys/bus/usb-serial/drivers/option1/new_id"
        Dbg "Write the vendor ID:$gCfgVendorId & product ID:$gCfgProductId."
    else
        Dbg "Not find the vendor ID & product ID!"
    fi

    if [ ! -z $gCfgVendorId2 ] && [ ! -z $gCfgProductId2 ]; then
        sh -c "echo $gCfgVendorId2 $gCfgProductId2 >> /sys/bus/usb-serial/drivers/option1/new_id"
        Dbg "Write the vendor ID2:$gCfgVendorId2 & product ID2:$gCfgProductId2."
    fi

    return 0
}

Tool_LoadPCIDriver()
{
    local drv_name="${1%\.ko}"
    local ret;

    local search_driver=$(lsmod | grep "mtk_pcie_wwan_*")
    local driver="${search_driver%% *}"
    if [ -z "$driver" ]; then
        modprobe ${drv_name}
        ret=$?
        if [ $ret -eq 0 ]; then
            Msg "Load the driver $drv_name"
            sleep 1
        else
            Msg "Load the driver $drv_name failed"
            return $ret
        fi
    fi

    return 0
}

Tool_IsSwCmd()
{
    local cmdset="EnableMonitor \
                    DisableMonitor \
                    StopMonitor \
                    GetMonitorState \
                    SetLogLevel "
    local force_en=0
    local isswcmd=0

    Dbg3 "Input command: $*"
    
    for i in $(echo $cmdset)
    do
        for j in $*
        do
            if [ "$i" = "$j" ]; then
                isswcmd=1
            fi
            if [ "$j" = "-f" ]; then
                force_en=1
            fi
        done
    done

    if [ $isswcmd -eq 1 ] && [ $force_en -eq 1 ]; then
        return 0
    else
        return 1
    fi
}

#====================================
#========== main function ===========
#====================================
#
# Show the version
#
if [ -e $gVersionFile ]; then
    . $gVersionFile
else
    gVersion="Unknow"
fi
echo "==============================================="
Msg "\t\t$gVersion"
echo "==============================================="

#
# Check permission
#
Common_iIsRoot
gRet=$?
[ $gRet -ne 0 ] && Echo "Please use 'sudo' to run $0." && exit 1

#
# For debug
#
if [ $# -ge 2 ]; then
    #eval gLastArg=\${$#}
    #gTmp=`echo "$gLastArg" | grep debug | cut -d'=' -f2`
    for i in $(echo $@)
    do
        gTmp=`echo "$i" | grep debug | cut -d'=' -f2`
        if [ ! -z $gTmp ] && [ $gTmp -ge 1 ] 2> /dev/null; then
            gDebug=$gTmp
            Msg "Debug level: $gDebug"
            break
        else
            gDebug=0
        fi
    done
fi

#
# Detect HW module
# if gSwCmdFlag is set to "1", the HW detection is bypass.
#
gSwCmdFlag=0
for i in $(seq 1 10)
do
    if [ $i -ne 1 ]; then
        eval _VID=\${gCfgVendorId$i}
        eval _PID=\${gCfgProductId$i}
    else
        _VID=$gCfgVendorId
        _PID=$gCfgProductId
    fi

    Dbg3 "_VID:$_VID, _PID:$_PID"

    if [ -z "$_VID" ];then
        Msg "Not detect the hardware '${gCfgModelName}${gCfgMultiModelName}'"
        Tool_IsSwCmd "$*"
        if [ $? -ne 0 ]; then
            exit 1
        else
            gSwCmdFlag=1
            break
        fi
    fi

    Common_iCheckModuleID $_VID $_PID $gCfgHwIface
    if [ $? -eq 0 ]; then
        break
    fi
done

#
# Check model
#
gModuleName=$gCfgModelName
Msg "Model: ${gModuleName}${gCfgMultiModelName}"

#
# Init error code ,log & monitor
#
MErr_Init
Log_Init
Monitor_Init

#
# Check device when input command is about hardware module
#
if [ $gSwCmdFlag -eq 0 ]; then
    #
    # Check & log with device node that is used by other process or not
    #
    AT_IsDevUse $gCfgExistPortSet
    gRet=$?
    if [ $gRet -eq 0 ]; then
        Msg "The device node of ttyUSBx is used by other process."
        exit 1
    fi

    #
    # Enable com port with driver "option"
    #
    AT_IsDevExist $gCfgExistPortSet
    gRet=$?
    #[ $gRet -ne 0 ] && Tool_LoadDriver && Dbg "Try to enable com port."
    if [ ! -z "$gCfgHwIface" ] && [ "$gCfgHwIface" = "$IFTYPE_PCI" ]; then
        if [ $gRet -ne 0 ]; then
            Tool_LoadPCIDriver $gCfgDriverName
            if [ $? -ne 0 ]; then
                Msg "Load PCI driver failed"
                exit 2
            fi
        fi
    else
        [ $gRet -ne 0 ] && Tool_LoadDriver && Dbg "Try to enable com port."
    fi
fi

#
# Import module
#
if [ -e "$gModuleDir/$gModuleName/$gModuleName.sh" ] ;then
    . $gModuleDir/$gModuleName/$gModuleName.sh
else
    gRet=$MErr_NOMODULE
    ExitIfError $gRet "($gRet) $(MErr_strCode2Msg $gRet)"
fi       

#
# Init 4g/5g module if not do it before
#
if [ ! -e $gModuleListFile ] || [ ! -e $gModuleCfgFile ]; then
    gRunCmd=Init
    ${gModuleName}_Init
    gRet=$?
    if [ $gRet -ge $MErr_Start ] && [ $gRet -le $MErr_End ]; then
        ExitIfError $gRet "($gRet) $(MErr_strCode2Msg $gRet)"
    else
        ExitIfError $gRet "($gRet) $gRetStr"
    fi
else
    #
    # Get module config
    #
    . $gModuleCfgFile
fi

#
# Init serial when input command is about hardware module
#
if [ $gSwCmdFlag -eq 0 ]; then
    #
    # Init serail
    #
    Dbg "[main] gDevNode: $gDevNode"
    InitSerial $gDevNode $gCfgAtBaudrate
    gRet=$?
    if [ $gRet -ne 0 ]; then
        gRunCmd=Init
        ${gModuleName}_Init
        gRet=$?
        if [ $gRet -ge $MErr_Start ] && [ $gRet -le $MErr_End ]; then
            ExitIfError $gRet "($gRet) $(MErr_strCode2Msg $gRet)"
        else
            ExitIfError $gRet "($gRet) $gRetStr"
        fi
    fi
fi

#
# Enable log or not
#
Log_GetLogLevel
gRet=$? && [ $gRet -ge $L_LEVEL2 ] && AT_EnableLog

#
# Run command
#
#gRunCmd=`cat $gModuleListFile | grep "^$1$"`
Dbg3 "Arguments: $*"
gArgList=`echo $* | sed 's/debug=[[:digit:]]*[[:digit:]]//g;s/-f//g;s/^ //g'`
Dbg3 "Arguments after parser: $gArgList"
#gInputCmd=`echo $@ | sed 's/debug=[[:digit:]]*[[:digit:]]//g;s/-f//g;s/^ //g' | cut -d' ' -f1`
gInputCmd=`echo $gArgList | cut -d' ' -f1`
gRunCmd=`cat $gModuleListFile | grep "^$gInputCmd$"`
Dbg "[main] Run command is $gRunCmd"
#if [ "$gRunCmd" = "$1" ] && [ ! -z "$1" ]; then
if [ "$gRunCmd" = "$gInputCmd" ] && [ ! -z "$gInputCmd" ]; then
    #shift
    #gArgList=$@ && gArgList=`echo $gArgList | sed 's/debug.*$//g'`
    #gArgList=$@ && gArgList=`echo $gArgList | sed 's/debug.*$//g' | sed 's/-f//g'`
    #gArgList=$@ && gArgList=`echo $gArgList | sed 's/debug=[[:digit:]]*[[:digit:]]//g;s/-f//g'`
    gArgList=`echo $gArgList | sed -e "s/$gInputCmd//g;s/^ //g"`
    Dbg3 "Arguments passed to module: $gArgList"
    ${gModuleName}_${gRunCmd} $gArgList
    gRet=$?
    if [ $gRet -ge $MErr_Start ] && [ $gRet -le $MErr_End ]; then
        echo  "\ndone"
        ExitIfError $gRet "($gRet) $(MErr_strCode2Msg $gRet)"
    else
        ExitIfError $gRet "($gRet) $gRetStr"
    fi
    
    if  [ "$gRunCmd" = "EnableMonitor" ]; then
	    systemctl stop rc-local
	    sleep 1
	    systemctl start rc-local
    fi	    

    echo  "\ndone"
else
    echo "Usage: $0 command"
    echo "command listed as below :"
    cat $gModuleListFile
    exit 1
fi

exit 0


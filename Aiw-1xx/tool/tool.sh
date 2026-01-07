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

#
# Import modules
#
. $gCommonDir/common.sh
. $gCommonDir/debug.sh
. $gCommonDir/log.sh
. $gCommonDir/parser.sh
. $gCommonDir/command.sh
. $gCommonDir/monitor_ctrl.sh

#
# The current command
#
gRunCmd="none"


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
# Detect HW module
#
Common_iCheckModuleID $gCfgVendorId $gCfgProductId
if [ $? -ne 0 ]; then
    Common_iCheckModuleID $gCfgVendorId2 $gCfgProductId2
    [ $? -ne 0 ] && Msg "Not detect the hardware '$gCfgModelName'" && exit 1
fi

#
# For debug
#
if [ $# -ge 2 ]; then
    eval gLastArg=\${$#}
    gTmp=`echo "$gLastArg" | grep debug | cut -d'=' -f2`
    if [ ! -z $gTmp ] && [ $gTmp -ge 1 ] 2> /dev/null; then
        gDebug=$gTmp
        Msg "Debug level: $gDebug"
    else
        gDebug=0
    fi
fi

#
# Check model
#
gModuleName=$gCfgModelName
Msg "Model: $gModuleName"

#
# Init error code ,log & monitor
#
MErr_Init
Log_Init
Monitor_Init

#
# Init WiFi with command module if not do it before
#
if [ ! -e $gCmdListFile ]; then
    gRunCmd=Init
    Cmd_Init
    gRet=$?
    if [ $gRet -ge $MErr_Start ] && [ $gRet -le $MErr_End ]; then
        ExitIfError $gRet "($gRet) $(MErr_strCode2Msg $gRet)"
    else
        ExitIfError $gRet "($gRet) $gRetStr"
    fi
fi

#
# Run command
#
gRunCmd=`cat $gCmdListFile | grep "^$1$"`
Dbg "[main] Run command is $gRunCmd"
if [ "$gRunCmd" = "$1" ] && [ ! -z "$1" ]; then
    shift
    gArgList=$@ && gArgList=`echo $gArgList | sed 's/debug.*$//g'`
    Cmd_${gRunCmd} $gArgList
    gRet=$?
    if [ $gRet -ge $MErr_Start ] && [ $gRet -le $MErr_End ]; then
        ExitIfError $gRet "($gRet) $(MErr_strCode2Msg $gRet)"
    else
        ExitIfError $gRet "($gRet) $gRetStr"
    fi
    
    echo  "\ndone $gRet"
else
    echo "Usage: $0 command"
    echo "command listed as below :"
    cat $gCmdListFile
    exit 1
fi

exit 0


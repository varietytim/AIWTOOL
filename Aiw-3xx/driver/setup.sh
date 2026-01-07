#============================================================================
# Setup script
#============================================================================
#!/bin/sh

#
# Work folders
#
gWorkdir=$(dirname $(readlink -f $0))
gTopdir=$(dirname $gWorkdir)
gSetupModuleDir="$gWorkdir/model"
gDriverCommonDir="$gTopdir/driver/common"
gToolCommonDir="$gTopdir/tool/common"
gTemplateDir="$gTopdir/template"
gModuleDir="$gTopdir/tool/module" # used by monitor.sh

#
# Golobal variables
#
. $gDriverCommonDir/script/setup_var.sh
. $gDriverCommonDir/script/ubuntu_rclocal_var.sh

#
# Import modules
#
. $gToolCommonDir/common.sh
. $gToolCommonDir/debug.sh
. $gToolCommonDir/monitor_ctrl.sh

#
# Others
#
gAction=''
gProfile=''
gModelList=''

Do_Init()
{
    local Name=''
    local TargetModel=$1

    #
    # Init for dial out
    #
    Name="dialout"
    if [ ! -e $gSetupModuleDir/$TargetModel/$Name.sh ]; then
        Setup_iPFGetValue "$gProfile" 'gPf_DialTemplate'
        Dbg "gPf_DialTemplate:($gRetStr)"
        Dbg "Copy $gTemplateDir/$Name/$gRetStr to $gSetupModuleDir/$TargetModel/$Name.sh"
        
        if [ -e $gTemplateDir/$Name/$gRetStr ]; then
            cp -ap $gTemplateDir/$Name/$gRetStr $gSetupModuleDir/$TargetModel/$Name.sh
        fi
    fi
        
    if [ ! -e $gWorkdir/$Name.sh ]; then
        Dbg "Create softlink: ln -s $gSetupModuleDir/$TargetModel/$Name.sh $gWorkdir/$Name.sh"
        ln -s $gSetupModuleDir/$TargetModel/$Name.sh $gWorkdir/$Name.sh
    fi

    #
    # Init for setup
    #
    Name="setup"
    if [ ! -e $gSetupModuleDir/$TargetModel/$Name.sh ]; then
        Setup_iPFGetValue "$gProfile" 'gPf_SetupTemplate'
        Dbg "gPf_SetupTemplate:($gRetStr)"
        Dbg "Copy $gTemplateDir/$Name/$gRetStr to $gSetupModuleDir/$TargetModel/$Name.sh"
        if [ -e $gTemplateDir/$Name/$gRetStr ]; then
            cp -ap $gTemplateDir/$Name/$gRetStr $gSetupModuleDir/$TargetModel/$Name.sh
        fi
    fi
}

Do_Clean()
{
    local Name=''
    local TargetModel=$1

    #
    # Clean for dial out
    #
    Name="dialout"
    #Setup_iPFGetValue "$gProfile" 'gPf_DialTemplate'
    #Dbg "gPf_DialTemplate:($gRetStr)"
    if [ -L "$gWorkdir/$Name.sh" ]; then
        Msg "Remove softlink: $gWorkdir/$Name.sh"
        rm -i "$gWorkdir/$Name.sh"
    fi
    
    if [ -e $gSetupModuleDir/$TargetModel/$Name.sh ]; then
        Msg "Remove $Name.sh: $gSetupModuleDir/$TargetModel/$Name.sh"
        rm -i $gSetupModuleDir/$TargetModel/$Name.sh
    fi

    #
    # Clean for setup
    #
    Name="setup"
    #Setup_iPFGetValue "$gProfile" 'gPf_SetupTemplate'
    #Dbg "gPf_SetupTemplate:($gRetStr)"
    if [ -e $gSetupModuleDir/$TargetModel/$Name.sh ]; then
        Msg "Remove $Name.sh: $gSetupModuleDir/$TargetModel/$Name.sh"
        rm -i $gSetupModuleDir/$TargetModel/$Name.sh
    fi
}

Do_Action()
{
    local TargetModel=$1
    local RestartFlag=$2
    local Action=$3
    local Args="$*"

    Dbg "All args: $Args"

    #
    # Import profile with specified target model
    #
    gProfile="$gSetupModuleDir/$TargetModel/profile"
    [ ! -e $gProfile ] && Msg "Not find the profile!" && exit 1
 
    #
    # Copy template by parsered profile if the target is not "clean"
    #
    [ "$Action" != "clean" ] && Do_Init "$TargetModel"

    #
    # Do setup
    #
    if [ -e $gSetupModuleDir/$TargetModel/setup.sh ]; then
        shift 3
        Dbg "Pass args to target: $*"
        $gSetupModuleDir/$TargetModel/setup.sh "$*" "model=$TargetModel"
    fi
       
    #
    # Clean files if the target is "clean"
    #
    [ "$Action" = "clean" ] && Do_Clean "$TargetModel"
   
    #
    # Restart rc-local to restart the monitor.sh
    #
    if [ "$RestartFlag" = "1" ]; then
        RcLocal_iIsEnable
        gRet=$?
        if [ $gRet -eq 0 ]; then
            Monitor_IsBootDialForRclocal
            gRet=$?
            if [ $gRet -eq 0 ]; then
                Monitor_DisableBootDialForRclocal
                Dbg "Disable dial out at booting for rc-local"
            fi
            
            RcLocal_iRestart
            gRet=$?
            [ $gRet -ne 0 ] && Msg "Restart rc-local failed" && exit 1
        fi
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
# To parser arguments
#
for arg in $@
do
    #echo "arg: $arg"
    if [ $gDebug -le 0 ]; then
        Dbg_iParserLevel "$arg"
        gRet=$?
        [ $gRet -ne 0 ] && gDebug=$gRet && Msg "Debug level: $gDebug"
    fi

    [ -z $gAction ] && [ "$arg" = "clean" ] && gAction="clean"
done

#
# Init monitor
#
Monitor_Init
Monitor_IsEnable
gRet=$?
if [ $gRet -eq 0 ]; then
    #Msg "Please to disable monitor by 'tool.sh DisableMonitor'."
    # exit 1
    echo 2 > $gModuleDir/monitor.ctrl
fi

#
# List of modules
#
n=0
for module in $(ls -c $gSetupModuleDir | sort); do
    eval "item$n"="$module"
    Dbg "$n) $module"
    
    Setup_iCheckHwModule "$gSetupModuleDir/$module/profile"
    if [ $? -eq 0 ]; then
        select=$n
        Dbg "Detect the module $module"

	    Setup_iGetMultiModelList "$gSetupModuleDir/$module/profile"
	    if [ $? -eq 0 ]; then
            gModelList="$gRetStr"
        fi
        #break
    fi
    
    n=$(( n + 1 ))
done

[ ! -z $select ] && eval selectmod="\$item$select"
Dbg "Total module: $n, selected module: $selectmod ($gModelList)"

#
# Check configuration to decide to uninstall with previous model
#
gPervModule=''
gPervModelList=''
Setup_iUCGetValue 'gCfgModelName'
if [ $? -eq 0 ]; then
    gPrevModule="$gRetStr"
    Dbg "Get previous model $gPrevModule"

    Setup_iUCGetValue 'gCfgMultiModelName'
    if [ $? -eq 0 ]; then
        gPervModelList="$gRetStr"
    fi
fi

#
# Do action
#
if [ "$gAction" = "clean" ]; then
    if [ ! -z $gPrevModule ]; then
        Dbg "Clean with previous model ${gPrevModule}${gPervModelList}"
        Msg "[${gPrevModule}${gPervModelList}: clean]"
        Do_Action $gPrevModule "1" "clean" $@
    fi
    
    if [ ! -z $selectmod ]; then
        if [ "$gPrevModule" != "$selectmod" ]; then
            Dbg "Clean with detection model $selectmod"
            Msg "[${selectmod}${gModelList}: clean]"
            Do_Action $selectmod "1" "clean" $@
        fi
    fi
else
    if [ ! -z $selectmod ]; then
        if [ ! -z "$gPrevModule" ] && [ "$selectmod" != "$gPrevModule" ]; then
            Dbg "Detection model ${selectmod}${gModelList} is different form previous model ${gPrevModule}${gPervModelList}"
            Dbg "Clean with previous model $gPrevModule"
            Msg "[${gPrevModule}${gPervModelList}: clean]"
            Do_Action $gPrevModule "0" "clean" "clean" "$@"
        fi

        Msg "[${selectmod}${gModelList}: setup]"
        Do_Action $selectmod "1" "init" $@
    else
        Msg "Not detect any hardware module!"
    fi
fi

Msg  "\nSetup complete."

exit 0


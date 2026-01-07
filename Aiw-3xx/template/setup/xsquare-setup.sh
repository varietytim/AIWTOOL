#============================================================================
# Setup script 
#============================================================================
#!/bin/sh

#
# The folders
#
gWorkdir=$(dirname $(readlink -f $0))
gTopdir="$(dirname $(dirname $(dirname $gWorkdir)))"
gDriverCommonDir="$gTopdir/driver/common"
gToolCommonDir="$gTopdir/tool/common"
gPlatformDir="$gWorkdir/platform"
gSetupModuleDir="$gWorkdir"

#
# Golobal variables
#
. $gWorkdir/profile
. $gDriverCommonDir/script/setup_var.sh
. $gDriverCommonDir/script/interact_flow.sh
. $gDriverCommonDir/script/mbim_var.sh
. $gDriverCommonDir/script/ubuntu_rclocal_var.sh
. $gDriverCommonDir/script/ubuntu_driver_var.sh
. $gDriverCommonDir/script/ubuntu_modem_manager.sh
. $gDriverCommonDir/script/ubuntu_package.sh

#
# Import modules
#
. $gToolCommonDir/common.sh
. $gToolCommonDir/debug.sh
. $gToolCommonDir/parser.sh

#
# For drivers
#
gDriverName="$gPf_DriverName"

#
# For information from user
#
gUsbmode="$gPf_RndisMode"
gUsername=''
gPassword=''
gAuth=''
gHwInfo=''
gHwIface=''

#
# Others
#
gModelName=''
gAction=''


#
# The flowchart of interaction with user to get information
#
GetInfoFromUser()
{
    local usbmode=$gPf_RndisMode
    local hwiface="$1"

    while :
    do
        # APN
        Interact_iGetString "Input your APN: " $gPf_ApnMaxLen
	    apn=$gRetStr
	    
        # Pin Code
        Interact_iGetString "Input your PIN code: " $gPf_PinMaxLen
        pin_code=$gRetStr
        
        # OP mode
        if [ "$hwiface" = "$IFTYPE_PCI" ]; then
            Interact_iListItem "Please select mode" "MBIM mode"
	else	
            Interact_iListItem "Please select mode" "MBIM mode" "RNDIS mode"
	fi

	mode=$?
        
        # Username & Password
        while :
        do
            apn_username=''
            apn_password=''
            apn_auth=''
            read -p "Input username/password [n/y]: " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
	            Interact_iGetString "Input your username: " "$gPf_UsrNameMaxLen"
                apn_username=$gRetStr
	            
                Interact_iGetString "Input your password: " "$gPf_PwdMaxLen"
                apn_password=$gRetStr

                # mode: 1 MBIM, 2 RNDIS
                if [ "$mode" = "1" ]; then
                    Interact_iListItem \
                        "Please select the authentication protocol" \
                        "PAP" \
                        "CHAP" \
                        "MSCHAPV2"
                else
                    Interact_iListItem \
                        "Please select the authentication protocol" \
                        "NONE" \
                        "PAP" \
                        "CHAP"
                fi
                apn_auth=$gRetStr
            fi

            break
	    done

        # Platform
        while :
        do
            Interact_iListDir "Select the platform as below:" "$gPlatformDir"
            platform="$gRetStr"
            if [ "$hwiface" = "$IFTYPE_PCI" ]; then
                echo "$platform" | grep "$IFTYPE_PCI" > /dev/null
                if [ $? -eq 0 ]; then
                    break
                else
                    Msg "Please select the platform with \"$IFTYPE_PCI\" string"
                fi
            fi
            
            if [ "$hwiface" = "$IFTYPE_USB" ]; then
                echo "$platform" | grep -v "$IFTYPE_PCI" > /dev/null
                if [ $? -eq 0 ]; then
                    break
                else
                    Msg "Please select the platform without \"$IFTYPE_PCI\" string"
                fi
            fi
        done

        echo "The below is your input:"
        
	    # Check APN is null string or not
	    if [ ! -z $apn ]; then 
	        Msg "APN: $apn"
	    else
	        apn="internet"
	        Msg "APN: $apn (default)"
	    fi

        # Check authentication protocol, username and password
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            if [ ! -z $apn_username ]; then
                Msg "Username: $apn_username"
            else
                apn_username="username"
                Msg "Username: $apn_username (default)"
            fi

            if [ ! -z $apn_password ]; then
                Msg "Password: $apn_password"
            else
                apn_password="password"
                Msg "Password: $apn_password (default)" 
            fi

            Msg "Auth: $apn_auth"
        fi

	    # Check pin code is null string or not
	    if [ ! -z $pin_code ]; then
            Msg "PIN Code: $pin_code"
	    fi

        if [ "$mode" = "1" ]; then
            Msg "Mode: MBIM mode"
            usbmode="$gPf_MbimMode"
        else
            Msg "Mode: RNDIS mode"
            usbmode="$gPf_RndisMode"
        fi

        # Show the platform
        Msg "Platform: $platform"

        #
        # Write the config if confirmed
        #
        gUsername=''
        gPassword=''
        gAuth=''
        local append=1
        local overwrite=0
        read -p "Input again [n/y]: " confirm
        if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then

            gMbimApn=$apn
            Setup_iWriteUsrCfg $overwrite "gCfgApn=$apn"
           
            # Check pin code is null string or not
            if [ ! -z $pin_code ]; then 
                Setup_iWriteUsrCfg $append "gCfgPinCode=$pin_code"
            fi

	        gUsbmode=$usbmode
            Setup_iWriteUsrCfg $append "gCfgUsbMode=$usbmode"
            Setup_iWriteUsrCfg $append "gCfgHwIface=$hwiface"

            if [ ! -z $apn_username ]; then
                gUsername=$apn_username
                gPassword=$apn_password
                gAuth=$apn_auth
                
                Setup_iWriteUsrCfg $append "gCfgUsername=$apn_username" \
                    "gCfgPassword=$apn_password" \
                    "gCfgApnAuth=$apn_auth"
            fi
        
            # Write the platform to configuration
            Setup_iAppendFileToUsrCfg "$gPlatformDir/$platform"
	    
            # Write the model name to configuration
            Setup_iWriteUsrCfg $append "gCfgModelName=${gModelName}"
            if [ ! -z "$gPf_MultiModelName" ]; then
                Setup_iWriteUsrCfg $append "gCfgMultiModelName=\"${gPf_MultiModelName}\""
            fi

            # Write the default setting to configuration
            Setup_iWriteUsrCfg $append "gCfgRndisMode=$gPf_RndisMode" \
                "gCfgMbimUsbmode=$gPf_MbimMode" \
                "gCfgVendorId=\"$gPf_VendorID\"" \
                "gCfgProductId=\"$gPf_ProductID\""
            if [ ! -z $gPf_VendorID2 ] && [ ! -z $gPf_ProductID2 ]; then
                Setup_iWriteUsrCfg $append \
                    "gCfgVendorId2=\"$gPf_VendorID2\"" \
                    "gCfgProductId2=\"$gPf_ProductID2\""
            fi
            if [ ! -z $gPf_VendorID3 ] && [ ! -z $gPf_ProductID3 ]; then
                Setup_iWriteUsrCfg $append \
                    "gCfgVendorId3=\"$gPf_VendorID3\"" \
                    "gCfgProductId3=\"$gPf_ProductID3\""
            fi

            # Write the delay time in seconds for driver probe
            Setup_iWriteUsrCfg $append "gCfgLoadDelay=$gPf_LoadDelay"
            Setup_iWriteUsrCfg $append "gCfgUnLoadDelay=$gPf_UnLoadDelay"
            
            # Write the delay time in seconds for this module to reset
            Setup_iWriteUsrCfg $append "gCfgResetDelay=$gPf_ResetDelay"
            
	    if [ $MTKDRV_BUILTIN -ne 0 ]; then
		    gPf_CustomMbimIface="wwan0"
		    gPf_CustomRndisIface="wwan0"
	    fi

            # Write the customer MBIM/RNDIS interface if needed
            if [ ! -z $gPf_CustomMbimIface ]; then
                Setup_iWriteUsrCfg $append "gCfgCustomMbimIface=$gPf_CustomMbimIface"
            fi
            if [ ! -z $gPf_CustomRndisIface ]; then
                Setup_iWriteUsrCfg $append "gCfgCustomRndisIface=$gPf_CustomRndisIface"
            fi

            # The method to get IP address by mbimcli
            if [ ! -z $gPf_GetIpByMbim ]; then
                Setup_iWriteUsrCfg $append "gCfgGetIpByMbim=$gPf_GetIpByMbim"
            fi

            # Disable reset method in monitor
            if [ ! -z $gPf_MtDisableReset ]; then
                Setup_iWriteUsrCfg $append "gCfgMtDisableReset=$gPf_MtDisableReset"
            fi
            
            # Init normal mode in monitor
            if [ ! -z $gPf_MtInitNormalMode ]; then
                Setup_iWriteUsrCfg $append "gCfgMtInitNormalMode=$gPf_MtInitNormalMode"
            fi
            
            # Init APN in monitor
            if [ ! -z $gPf_MtInitApn ]; then
                Setup_iWriteUsrCfg $append "gCfgMtInitApn=$gPf_MtInitApn"
            fi

            # Append the driver name with PCIe interface
            Setup_iWriteUsrCfg $append gCfgDriverName=$gPf_DriverName
            break
        fi

    done
}

SetConfig()
{
    local ret;

    #
    # For auto service
    #
    read -p "Write configuration to system [n/y]: " confirm
    if [ "$confirm" = "y" ]; then
        if [ -z $gPf_BootDelay ]; then
            RcLocal_iWriteScript 50
        else
            RcLocal_iWriteScript $gPf_BootDelay
        fi
        RcLocal_iCopyToSystem
    fi

    #
    # For mbim config
    #
    MbimCfg_iWriteCfg $gMbimApn $gUsername $gPassword $gAuth
    MbimCfg_iCopyToSystem

    #
    # Enable auto service
    #
    RcLocal_iIsEnable
    ret=$?
    if [ $ret -ne 0 ]; then
        RcLocal_iEnable
        Dbg "Enable rc-local service."
    else
        Dbg "Rc-local is already enabled."
    fi
}

CheckModemManager()
{
    local ret;

    ModemMgr_iIsEnable
    ret=$?
    if [ $ret -eq 0 ]; then
        read -p "We need to disable ModemManager & power recycle [n/y]: " confirm
        if [ "$confirm" = "y" ]; then
            ModemMgr_iDisable
            poweroff
            exit 0
        fi

        Msg "Exit due to ModemManager enabled."
        exit 0
    fi

    return 0
}

InstallPackages()
{
    #apt-get update
    Package_iInstall
}

########### main function ###########

#
# Show the version
#
if [ -e $gVersionFile ]; then
    . $gVersionFile
else
    gVersion="Unknow"
fi

Common_iIsParent
if [ $? -eq 0 ]; then
    Echo "==============================================="
    Msg "\t\t$gVersion"
    Echo "==============================================="
fi

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
    [ -z $gModelName ] && Parser_KeyValue $arg 'model' '=' && [ $? -eq 0 ] && gModelName=$gRetStr && Dbg "Input Model Name: $gModelName"
    [ -z $gAction ] && [ "$arg" = "clean" ] && gAction="clean"
done

#
# Fill in model name automatically
#
if [ -z $gModelName ]; then
    gModelName=`pwd`
    gModelName=${gModelName##*/}
fi

#
# Check HW module
#
if [ "$gAction" != "clean" ]; then
    Setup_iCheckHwModule "$gSetupModuleDir/profile"
    if [ $? -eq 0 ]; then
        gHwInfo="$gRetStr"
    else
        Msg "Not detect the hardware '$gModelName'"
        exit 1
    fi

    Common_iCheckHwIface "$gHwInfo"
    if [ $? -eq 0 ]; then
        if [ "$gRetStr" = "$IFTYPE_USB" ]; then
            gHwIface="$IFTYPE_USB"
        else
            gHwIface="$IFTYPE_PCI"
        fi
    else
        Msg "Detect hardware interface failed"
        exit 1
    fi
fi

#
# Action
#
MTKDRV_BUILTIN=0
if [ "$gAction" != "clean" ]; then
    #
    # Install driver
    #
    Common_iIsFileExist "$gDriverPath/$gDriverName"
    if [ $? -eq 1 ]; then
            Msg "Prepare some packages to install."
            InstallPackages
            
           if [ "$gHwIface" = "$IFTYPE_PCI" ]; then
	        MTKDRV_BUILTIN=`lsmod | grep mtk_t7xx | wc -l`
	        if [ $MTKDRV_BUILTIN -eq 0 ]; then
                    Msg "Setup driver....."
                    Driver_iSetup "${gWorkdir}/driver/$gPf_DriverFolderName" \
                            "$gDriverName" \
                            "${gWorkdir}/driver"
	        else
    	            if [ ! -e /dev/ttyC0 ]; then
			ln -s /dev/wwan0at0 /dev/ttyC0
			ln -s /dev/wwan0mbim0 /dev/ttyCMBIM0
	            fi		
	        fi	    
            fi   
    else
            Msg "Driver is installed before."
    fi

    #
    # Get information from user
    #   
    GetInfoFromUser "$gHwIface"

    #
    # Set config
    #
    SetConfig

    #   
    # Check ModemManager
    #
    CheckModemManager
else
    #
    # Before remove the driver, stop the mbim-proxy
    #
    gPid=`ps ax | grep -w "[m]bim-proxy" | sed 's/^[ \t]*//g' | cut -d' ' -f1`
    if [ ! -z "$gPid" ]; then
        Dbg "To stop mbim-proxy with pid $gPid"
        kill -9 $gPid > /dev/null
    fi 
    Driver_iClean "${gWorkdir}/driver/$gPf_DriverFolderName" "$gDriverName"
    if [ $? -eq 0 ]; then
        RcLocal_iClean
        MbimCfg_iClean
        Setup_iClean
        
        #
        # Rescan PCIe device with AIW-357
        #
        sh -c "echo 1 > /sys/bus/pci/rescan"

        Msg "Clean target done."
    else
        Msg "Clean target failed!"
    fi
fi


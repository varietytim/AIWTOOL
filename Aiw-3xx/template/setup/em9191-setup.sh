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
#. $gDriverCommonDir/script/ubuntu_driver_var.sh
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
#gDriverName="$gPf_DriverName"

#
# For information from user
#
#gUsbmode="$gPf_RmNetMode"
gUsername=''
gPassword=''
gAuth=''

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
    #local usbmode=$gPf_RmNetMode

    while :
    do
        # APN
        Interact_iGetString "Input your APN: " $gPf_ApnMaxLen
	    apn=$gRetStr
	    
        # Pin Code
        Interact_iGetString "Input your PIN code: " $gPf_PinMaxLen
        pin_code=$gRetStr
        
        # USB mode
        #Interact_iListItem "Please select mode" "RmNet mode" "MBIM mode"
	    #mode=$?
        
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

                #if [ "$mode" = "2" ]; then
                    Interact_iListItem \
                        "Please select the authentication protocol" \
                        "PAP" \
                        "CHAP" \
                        "MSCHAPV2"
                #else
                #    Interact_iListItem \
                #        "Please select the authentication protocol" \
                #        "NONE" \
                #        "PAP" \
                #        "CHAP" \
                #        "PAP_CHAP"
                #fi
                apn_auth=$gRetStr
            fi

            break
	    done

        # Platform
        Interact_iListDir "Select the platform as below:" "$gPlatformDir"
        platform=$gRetStr

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

        #if [ "$mode" = "2" ]; then
        #    Msg "Mode: MBIM mode"
        #    usbmode="$gPf_MbimMode"
        #else
        #    Msg "Mode: RmNet mode"
        #    usbmode="$gPf_RmNetMode"
        #fi

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

	        #gUsbmode=$usbmode
            #Setup_iWriteUsrCfg $append "gCfgUsbMode=$usbmode"

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
            #if [ -z $gModelName ]; then
            #    gModelName=`pwd`
            #    gModelName=${gModelName##*/}
            #fi
            Setup_iWriteUsrCfg $append "gCfgModelName=${gModelName}"
            
            # Write the default setting to configuration
            Setup_iWriteUsrCfg $append "gCfgRmNetUsbmode=$gPf_RmNetMode" \
                "gCfgMbimUsbmode=$gPf_MbimMode" \
                "gCfgVendorId=\"$gPf_VendorID\"" \
                "gCfgProductId=\"$gPf_ProductID\""
            if [ ! -z $gPf_VendorID2 ] && [ ! -z $gPf_ProductID2 ]; then
                Setup_iWriteUsrCfg $append \
                    "gCfgVendorId2=\"$gPf_VendorID2\"" \
                    "gCfgProductId2=\"$gPf_ProductID2\""
            fi

            # Write the delay time in seconds for this module to reset
            Setup_iWriteUsrCfg $append "gCfgResetDelay=$gPf_ResetDelay"
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
        read -p "We need to disable ModemManager & reboot [n/y]: " confirm
        if [ "$confirm" = "y" ]; then
            ModemMgr_iDisable
            reboot
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
    
    [ -z $gModelName ] && Parser_KeyValue $arg 'model' '=' && [ $? -eq 0 ] && gModelName=$gRetStr && Msg "Model Name: $gModelName"
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
    [ $? -ne 0 ] && Msg "Not detect the hardware '$gModelName'" && exit 1
fi

#
# Action
#
if [ "$gAction" != "clean" ]; then
    #Msg "Prepare some packages to install."
    InstallPackages

    #
    # Get information from user
    #   
    GetInfoFromUser

    #
    # Set config
    #
    SetConfig

    #   
    # Check ModemManager
    #
    CheckModemManager
else
    RcLocal_iClean
    MbimCfg_iClean
    Setup_iClean
    Msg "Clean target done."
fi

#Msg "Setup complete."

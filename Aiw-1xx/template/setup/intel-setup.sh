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
. $gDriverCommonDir/script/ubuntu_service_var.sh
#+. $gDriverCommonDir/script/ubuntu_driver_var.sh
. $gDriverCommonDir/script/ubuntu_firmware_var.sh
. $gDriverCommonDir/script/wpa_supplicant_cfg.sh
. $gDriverCommonDir/script/ubuntu_wpa_supplicant.sh
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
#+gDriverName="$gPf_DriverName"
gFwName="$gPf_FwName"
gFwVersionFilter="$gPf_FwVersion"
#gPf_FwName="iwlwifi-ty-a0-gf-a0-59.ucode"
#gPf_FwVersion="iwlwifi-ty-a0-gf-a0"
#
# For information from user
#
gPassword=''
gSsid=''

#
# Security type
#
gstrSTPersonal="WPA2-Personal"
gstrSTPersonalFt="WPA2-Personal-FT"
gstrSTEnterprise="WPA2-Enterprise"
gstrSTNone="None"

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
    local security_type;
    local fastroam_en=0

    while :
    do
        # SSID
        Interact_iGetString "Input your SSID: " 128
        local ssid="$gRetStr"
	   
        # Security type
        Interact_iListItem \
                        "Please select the security type" \
                        "$gstrSTPersonal" \
                        "$gstrSTPersonalFt" \
                        "$gstrSTEnterprise" \
                        "$gstrSTNone"
        security_type="$gRetStr"
        
        if [ "$security_type" = "$gstrSTEnterprise" ]; then
            Interact_iGetString "Input your username: " 32
            local eap_id="${gRetStr}"
        fi

        # Password
        if [ "$security_type" != "$gstrSTNone" ]; then
            Interact_iGetPassword "Input your password: " 63
            local password="${gRetStr}"
        fi

        # Roaming parameters
        while :
        do
            local roam_en=0
            local rssi_threshold=''
            local rssi_hysterisis=''
            local scan_long_interval=''
            local scan_short_interval=''
            read -p "Enable roam [n/y]: " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                roam_en=1

                if [ "$security_type" = "$gstrSTPersonalFt" ]; then
                    fastroam_en=1
                fi

                # RSSI threshold
                Interact_iGetString "RSSI threshold: " 3
                rssi_threshold=$gRetStr
        
                # RSSI hysterisis
                #Interact_iGetString "RSSI hysterisis: " 1
                #rssi_hysterisis=$gRetStr

                # Scan long interval
                Interact_iGetString "Scan long interval: " 8
                scan_long_interval=$gRetStr
        
                # Scan short interval
                Interact_iGetString "Scan short interval: " 8
                scan_short_interval=$gRetStr
            fi

            break
	    done

        # Platform
        Interact_iListDir "Select the platform as below:" "$gPlatformDir"
        local platform=$gRetStr

        echo "The below is your input:"
        
	    # Check SSID, security type and password is null string or not
	    if [ ! -z "$ssid" ]; then 
	        Msg "SSID: $ssid"
	    else
	        ssid="Advantech"
	        Msg "SSID: $ssid (default)"
	    fi

        if [ ! -z "$security_type" ]; then
            Msg "Security type: $security_type"
        else
            security_type="$gstrSTPersonal"
            Msg "Security type: $security_type (default)"
        fi

        if [ "$security_type" = "$gstrSTEnterprise" ]; then
            if [ ! -z "$eap_id" ]; then
                Msg "Username: $eap_id"
            else
                eap_id="advantech"
                Msg "Username: $eap_id (default)"
            fi     
        fi

        if [ ! -z "$password" ]; then
            Dbg "Password: $password"
        else
            if [ "$security_type" != "$gstrSTNone" ]; then
                password="password"
                Dbg "Password: $password (default)"
            fi
        fi
        
        # Check authentication protocol, username and password
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            if [ ! -z $rssi_threshold ] && Common_iIsInteger $rssi_threshold; then
                Msg "RSSI threshold: $rssi_threshold"
            else
                rssi_threshold="-75"
                Msg "RSSI threshold: $rssi_threshold (default)"
            fi
            
            if [ ! -z $rssi_hysterisis ] && Common_iIsInteger $rssi_hysterisis; then
                Msg "RSSI hysterisis: $rssi_hysterisis"
            else
                rssi_hysterisis="4"
                Msg "RSSI hysterisis: $rssi_hysterisis (default)"
            fi
            
            if [ ! -z $scan_long_interval ] && Common_iIsInteger $scan_long_interval; then
                Msg "Scan long interval: $scan_long_interval"
            else
                scan_long_interval="120"
                Msg "Scan long interval: $scan_long_interval (default)"
            fi
            
            if [ ! -z $scan_short_interval ] && Common_iIsInteger $scan_short_interval; then
                Msg "Scan short interval: $scan_short_interval"
            else
                scan_short_interval="30"
                Msg "Scan short interval: $scan_short_interval (default)"
            fi
        fi

        # Show the platform
        Msg "Platform: $platform"

        #
        # Write the config if confirmed
        #
        #gPassword=''
        local append=1
        local overwrite=0
        read -p "Input again [n/y]: " confirm
        if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
            # Write the configuration by user input
            gSsid="${ssid}"
            gPassword="${password}"
            Setup_iWriteUsrCfg $overwrite "gCfgSsid='${ssid}'"
            if [ ! -z $eap_id ]; then
                gEapId="${eap_id}"
                Setup_iWriteUsrCfg $append "gCfgEapId='${eap_id}'"
            fi
            Setup_iWriteUsrCfg $append "gCfgPassword='${password}'"

            if [ $roam_en -eq 1 ]; then
                Setup_iWriteUsrCfg $append "gCfgRoamEnable=$roam_en" \
                    "gCfgRssiThreshold=$rssi_threshold" \
                    "gCfgRssiHysterisis=$rssi_hysterisis" \
                    "gCfgScanLongInterval=$scan_long_interval" \
                    "gCfgScanShortInterval=$scan_short_interval"
            else    
                Setup_iWriteUsrCfg $append "gCfgRoamEnable=$roam_en"
            fi

            Setup_iWriteUsrCfg $append "gCfgFastRoamEnable=$fastroam_en"
            gFastRoamEn=$fastroam_en

            # Write the platform to configuration
            Setup_iAppendFileToUsrCfg "$gPlatformDir/$platform"

            # Write the model name to configuration
            Setup_iWriteUsrCfg $append "gCfgModelName=${gModelName}"
            
            # Write the profile setting to configuration
            Setup_iWriteUsrCfg $append  \
                "gCfgVendorId=\"$gPf_VendorID\"" \
                "gCfgProductId=\"$gPf_ProductID\""
            if [ ! -z $gPf_VendorID2 ] && [ ! -z $gPf_ProductID2 ]; then
                Setup_iWriteUsrCfg $append \
                    "gCfgVendorId2=\"$gPf_VendorID2\"" \
                    "gCfgProductId2=\"$gPf_ProductID2\""
            fi

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
        Service_iWriteScript 0
        Service_iCopyToSystem
    fi

    #
    # Enable auto service
    #
    Service_iIsEnable
    ret=$?
    if [ $ret -ne 0 ]; then
        Service_iEnable
        Dbg "Enable boot service."
    else
        Dbg "boot service is already enabled."
    fi

    #
    # Write the configuration with wpa_supplicant
    #
    WpasCfg_iWriteCfg "$gSsid" "$gPassword" "$gEapId" $gFastRoamEn
}

CheckWpaService()
{
    local ret;

    WpaS_iIsEnable
    ret=$?
    if [ $ret -eq 0 ]; then
        WpaS_iDisable
        Msg "To disable wpa_supplicant service."
    else
        Dbg "wpa_supplicant service is disabled"
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
    #
    # Install firmware if it's not ready
    #
    if ! WiFiFW_iIsFwReady; then
        Common_iIsFileExist "$gFirmwarePath/$gFwName"
        if [ $? -eq 1 ]; then
            Msg "Prepare some packages to install."
            InstallPackages

            Msg "Setup firmware....."
            WiFiFW_iSetup "${gWorkdir}/firmware/$gPf_FwFolderName" \
                            "$gFwName" \
                            "${gWorkdir}/firmware" \
                            "$gFwVersionFilter"
        else
            Msg "The firmware is installed before."
        fi

        if ! WiFiFW_iIsFwReady; then
            Msg "The firmware is loaded failed."
            exit 1
        fi
    fi

    #
    # Get information from user
    #   
    GetInfoFromUser
    
    #
    # Set config
    #
    SetConfig

    #   
    # Check wpa_supplicant service
    #
    CheckWpaService

    #
    # Enable WiFi and check interface
    #
    rfkill unblock wifi

else
    WiFiFW_iClean "${gWorkdir}/firmware/$gPf_FwFolderName" "$gFwName"
    if [ $? -eq 0 ]; then
        Service_iClean
        Setup_iClean
        Msg "Clean target done."
    else
        Msg "Clean target failed!"
    fi
fi

exit 0

#!/bin/sh

#
# This script is aim to create configuration for
# wpa_supplicant.
#
gWpasCfgFile="$gUsrCfgdir/wpas.conf"


#
# Write configuration with wpa_supplicatn
#
# param[in] $1: the string of ssid.
# param[in] $2: the string of password.
# param[in] $3: the string of EAP ID.
# param[in] $4: the bool of fast roam.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
WpasCfg_iWriteCfg()
{
    local ssid="$1"
    local password="$2"
    local eap_id="$3"
    local fastroam_en="$4"

    #if [ -z $ssid  ] && [ -z $password ]; then
    if [ -z $ssid  ]; then
        return 1    
    fi

    echo 'ctrl_interface=/run/wpa_supplicant' > $gWpasCfgFile
    echo 'update_config=1' >> $gWpasCfgFile

    #
    # Start of network block
    #
    echo "\nnetwork={" >> $gWpasCfgFile
    echo "\tssid=\"${ssid}\"" >> $gWpasCfgFile
    
    #
    # SSID & password
    #
    if [ ! -z "$password" ]; then
        if [ -z $eap_id ]; then
            wpa_passphrase "$ssid" "$password" | grep psk >> $gWpasCfgFile
            if [ $fastroam_en -eq 1 ]; then
                echo "\tkey_mgmt=FT-PSK" >> $gWpasCfgFile
            fi
        else
            echo "\tkey_mgmt=WPA-EAP" >> $gWpasCfgFile
            echo "\tidentity=\"${eap_id}\"" >> $gWpasCfgFile
            echo "\tpassword=\"${password}\"" >> $gWpasCfgFile
        fi
    else
        echo "\tkey_mgmt=NONE" >> $gWpasCfgFile
    fi
    
    #
    # End of network block
    #
    echo '}' >> $gWpasCfgFile

    sync;sync;sync
    chmod 755 $gWpasCfgFile

    return 0
}

#
# To clean MBIM configuration in system
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
WpasCfg_iClean()
{
    #
    # Remove MBIM configuration
    #
    if [ -e "$gWpasCfgFile" ]; then
        rm -i "$gWpasCfgFile"
    fi

    return 0
}


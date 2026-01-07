#!/bin/sh

#
# The folders 
#
gWorkdir=$(dirname $(readlink -f $0))
gTopdir="$(dirname $(dirname $(dirname $gWorkdir)))"
gCommonDir=${gTopdir}/tool/common
gDriverCommonDir=${gTopdir}/driver/common

#
# Golobal variables
#
. $gCommonDir/common_var.sh
. $gCommonDir/mbim.sh
. $gDriverCommonDir/script/mbim_var.sh
. $gDriverCommonDir/script/mbim_driver.sh
. $gDriverCommonDir/script/option_driver.sh

#
# Import modules
#
. $gCommonDir/common.sh
. $gCommonDir/debug.sh
. $gCommonDir/at_serial.sh
. $gCommonDir/log.sh
. $gCommonDir/parser.sh
. $gCommonDir/module_err.sh
. $gCommonDir/dialout_err.sh

#
# To find the tool.sh
#
gToolCmd="$gToolDir/tool.sh"

gModuleDir="$gTopdir/tool/module" # used by monitor.sh

#
# Init error code & log
#
MErr_Init
DErr_Init
Log_Init


#
# Import module
#
if [ -e "$gModuleDir/$gCfgModelName/$gCfgModelName.sh" ] ;then
    . $gModuleDir/$gCfgModelName/$gCfgModelName.sh
    . $gCommonDir/module_var.sh
else
    gRet=$MErr_NOMODULE
    ExitIfError $gRet "($gRet) $(MErr_strCode2Msg $gRet)"
fi


Msg "Module is $gCfgModelName"
gDevNode=/dev/ttyUSB2


Option_LoadDriver()
{
    if [ ! -z $gCfgVendorId ] && [ ! -z $gCfgProductId ]; then
        OptionDrv_Load $gCfgVendorId $gCfgProductId
        Dbg "[ret:$?] Write the vendor ID:$gCfgVendorId & product ID:$gCfgProductId."
    fi

    if [ ! -z $gCfgVendorId2 ] && [ ! -z $gCfgProductId2 ]; then
        OptionDrv_Load $gCfgVendorId2 $gCfgProductId2 'append'
        Dbg "[ret:$?]: Write the vendor ID2:$gCfgVendorId2 & product ID2:$gCfgProductId2."
    fi
}

Option_UnLoadDriver()
{
    local ret;
    local ii;

    ii=0
    while :
    do
        OptionDrv_UnLoad
        ret=$?
        if [ $ret -eq 0 ]; then
            break
        else
            ii=$((ii+1))
            sleep 1
        fi

        if [ $ii -ge 5 ]; then
            ExitIfError $ret "Unload option driver failed!"
        fi
    done
}

Mbim_LoadDriver()
{
    #
    # Remove option and reload the MBIM driver
    #
    Option_UnLoadDriver

    #
    # Load the MBIM driver
    #
    MbimDrv_LoadDriver 0.5

    #
    # Reload the option driver to enable the ttyUSBx
    #
    Option_LoadDriver
    # ReInitSerial
}



RunTool()
{
    $gToolCmd $@ > /dev/null

    local ret=$?
    return $ret
}


SetUsbMode()
{
    ${gCfgModelName}_iSetUsbMode $gCfgUsbMode
    local ret=$?
    if [ $ret -eq 0 ] || [ $ret -eq $MErr_ATNOPID ]; then
        Msg "Set to usbmode successful."
        Msg "Wait for $gCfgResetDelay seconds due to usbmode changed"
        sleep $gCfgResetDelay
        RunTool Reset
        Msg "Wait for $gCfgResetDelay seconds due to module reboot"
        sleep $gCfgResetDelay
        RunTool Init
    else
        # Msg "Set to usbmode failed."
        return $DErr_SETMODE
    fi

    return 0
}


Mbim2RmNet()
{
    local ret;

    #
    # Down the network interface
    #
    MbimDrv_IsDriverReady
    if [ $? -eq 0 ]; then
        Common_iFindNetInterface "$gDefMbimIface" "$gNetIfaceFlag"
        gCurMbimIface=$gRetStr

        local ret=`ifconfig | grep $gCurMbimIface | wc -l`
        if [ ! -z "$ret" ] && [ $ret -ge 1 ]; then
            Dbg "ifconfig $gCurMbimIface down"
            ifconfig $gCurMbimIface down
        fi
    fi

    #
    # Remove the MBIM driver
    #
    MbimDrv_UnloadDriver

    modprobe -r qmi_wwan
    #
    # Set to MBIM mode
    #
    SetUsbMode $gCfgUsbMode
    if [ $? -eq 0 ]; then
        Msg "Set usbmode to rmnet success!"
    fi

    return 0
}

RmNet2Mbim()
{
    #
    # Set to MBIM mode without removed RNDIS driver
    #
    SetUsbMode $gCfgUsbMode
    if [ $? -eq 0 ]; then
        Msg "Set usbmode to mbim success!"
    fi

    #
    # Reload the MBIM driver
    #

    Mbim_LoadDriver
    ret=$?

    return $ret
}




	
#
# Running with RmNet
#
	if [ $gCfgUsbMode -eq $gCfgRmNetUsbmode ]; then
		cp -a ${gTopdir}/template/dialout/telit-qmi-wwan-dialout.sh ${gTopdir}/driver/model/${gCfgModelName}/
		chmod +x ${gTopdir}/driver/model/${gCfgModelName}/telit-qmi-wwan-dialout.sh
		Msg "Module $gCfgModelName works in RmNet mode"
		Mbim2RmNet
		gDialoutScript=${gTopdir}/driver/model/${gCfgModelName}/telit-qmi-wwan-dialout.sh
		$gDialoutScript $1
		gRet=$?
		Msg "Dialout complete."
		exit $gRet
	fi

#
# Running with MBIM
#
	if [ $gCfgUsbMode -eq $gCfgMbimUsbmode ]; then
		Msg "Module $gCfgModelName works in MBIM mode"
		RmNet2Mbim	
		cp -a ${gTopdir}/template/dialout/ubuntu-mbim-dialout.sh ${gTopdir}/driver/model/${gCfgModelName}/
		chmod +x ${gTopdir}/driver/model/${gCfgModelName}/ubuntu-mbim-dialout.sh
		gDialoutScript=${gTopdir}/driver/model/${gCfgModelName}/ubuntu-mbim-dialout.sh
		$gDialoutScript $1
		gRet=$?
		Msg "Dialout complete."
		exit $gRet
	fi

Msg "Dialout complete."
exit $gRet

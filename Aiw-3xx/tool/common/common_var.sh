#!/bin/sh

#
# Module folder
#
gToolDir=${gTopdir}/tool
gModuleDir=${gToolDir}/module

#
# To find the version
#
gVersionFile="$gTopdir/../version"

#
# User configuration by setup.sh
# Note that this file is read-only with tool.sh, dialout.sh.
#
gSetupEnvFile="$gTopdir/driver/common/script/setup_var.sh"
. $gSetupEnvFile    # defined in common_var.sh
. $gCfgFile         # defined in setup_var.sh

#
# Log
#
gATCmdDir=/tmp/module_at_cmd
gATLogFile=/tmp/module_at.log
gLogFile=/tmp/monitor.log
gLogLevelFile=${gModuleDir}/log.level
gPinLogFile=/tmp/set_pin.log

#
# Return variable
#
gRetStr="none"
gRet=1

#
# Default network interface
#
NETIF_GOBINET="GobiNet"
NETIF_MBIM="MBIM"
NETIF_QMI_WWAN="QMI"
NETIF_RNDIS="RNDIS"


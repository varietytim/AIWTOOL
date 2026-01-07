#!/bin/sh

#
# Module folder
#
gToolDir=${gTopdir}/tool
gMonitorDir=${gToolDir}/monitor
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
gWifiCmdDir=/tmp/wifi_cmd
gLogFile=/tmp/monitor.log
gLogLevelFile=${gMonitorDir}/log.level

#
# Return variable
#
gRetStr="none"
gRet=1

#
# Default WiFi interface
#
DEF_WIFI_IF="wlp*"

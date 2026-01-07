#!/bin/sh

#
# Golobal variables
#
IFTYPE_USB='usb'
IFTYPE_PCI='pci'
IFTYPE_ALL='all'


ExitIfError()
{
    if [ $1 -ne 0 ]; then
        Dbg3 "err: $2"
        exit $1
    fi
}

Msg()
{
    echo "\033[33m$1\033[0m"
}

Echo()
{
    echo "$1"
}

Common_iIsInteger()
{
    case "${1#[+-]}" in
        (*[![:digit:]]*) return 1 ;;
        ('') return 1 ;;
        (*) return 0 ;;
    esac
}

#
# To find the network interface
#
# param[in] $1: the string of network interface we want to find
# return  On success, interface name is returned.
#         On error, others is returned.
#
Common_iFindNetInterface()
{
    [ -z $1 ] && return 1

    local tmp_file="/tmp/$1_rename"
    local ret;

    if [ "$1" = "ccmni0" ]; then
        ifconfig ccmni0
	if [ $? -eq 0 ]; then
		gRetStr="ccmni0"
		return 0
	fi	
    fi	    

    for ifname in $(ls /sys/class/net); do
      if [ "$ifname" != "lo" ]; then	
	DrvName=`ethtool -i $ifname | grep driver`
	Res=`echo "${DrvName}" | grep -i "$1" | wc -l`
	if [ $Res -eq 1 ]; then
		if  [ ! -z $ifname ]; then
       	      		echo "$ifname" > $tmp_file
		fi
	fi
      fi	
    done
	
    gRetStr=`cat $tmp_file`
    return $?
}

Common_iCheckNetIface()
{
    local ret;

    [ -z $1 ] && return 1

    ifconfig | grep -w "$1:" > /dev/null 2>&1
    ret=$?

    return $ret
}

#
# Check file whether exist or not
#
# param[in] $1: the path to find the file.
#
# return  Exist, zero is returned.
#         Not exist, 1 is returned.
#         On error, others is returned.
#
Common_iIsFileExist()
{
    [ -z $1 ] && return 2

    if [ ! -e "$1" ]; then
        return 1;
    else
        return 0;
    fi
}

#
# Check the user whether root or not
#
# param[in] none.
#
# return  Is root, zero is returned.
#         Not root, others is returned.
#
Common_iIsRoot()
{
    [ "$USER" = "root" ] && return 0

    #
    # This is special case with rc.local while booting
    #
    [ -z "$USER" ] && return 0

    return 1
}

#
# Check current & expected kernel versions
# param[in] $1: expected kernel version
# param[in] $2: comparison operators
# return  On success, zero is returned.
#         On error, others is returned.

Common_iKernelVerCheck()
{
current_version=$(uname -r | cut -f1 -d-)
required_version=$1
op=$2

# Compare the versions
dpkg --compare-versions "$current_version" "$op" "$required_version"
if [ $? -eq 0 ]; then
    return 0
else
    echo "Kernel version $current_version is not supported."
    return 1
fi
}


#
# Check vendor ID and product ID
#
# param[in] $1: the string of vendor ID
# param[in] $2: the string of product ID
# param[in] $3: the interface type with USB, PCI or both
# param[out] gRetStr: the string of vendor & product ID & interface.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Common_iCheckModuleID()
{
    local vendorId=$1
    local productId=$2
    local iftype=$3

    if [ -z $vendorId ] || [ -z $productId ]; then
        return 1
    fi

    vendorId=`echo $vendorId | sed 's/0x//g'`
    productId=`echo $productId | sed 's/0x//g'`

    if [ -z "$iftype" ] || [ "$iftype" = "$IFTYPE_USB" ] || [ "$iftype" = "$IFTYPE_ALL" ]; then 
        lsusb | grep "$vendorId:$productId" > /dev/null
        if [ $? -eq 0 ]; then
            gRetStr="$vendorId:$productId:$IFTYPE_USB"
            Dbg3 "Detecting module with $vendorId:$productId by $IFTYPE_USB interface"
            return 0
        fi
    fi
    
    if [ "$iftype" = "$IFTYPE_PCI" ] || [ "$iftype" = "$IFTYPE_ALL" ]; then 
        lspci -nn | grep "$vendorId:$productId" > /dev/null
        if [ $? -eq 0 ]; then
            gRetStr="$vendorId:$productId:$IFTYPE_PCI"
	    if [ "$vendorId:$productId" = "14c3:4d75" ]; then
		# AIW-357 PCI kernel version check    
	        Common_iKernelVerCheck "5.19.0" "lt"
	        if [ $? -ne 0 ]; then
	             return 2
                fi
            fi

            Dbg3 "Detecting module with $vendorId:$productId by $IFTYPE_PCI interface"
            return 0
        fi
    fi

    return 2
}

#
# Check hardware interface
#
# param[in] $1: the string of vendor & product ID & interface.
#           Note that this string is created by Common_iCheckModuleID
# param[out] gRetStr: IFTYPE_USB or IFTYPE_PCI.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Common_iCheckHwIface()
{
    local hwinfo="$1"

    if [ -z $hwinfo ]; then
        return 1
    fi

    echo "$hwinfo" | grep "$IFTYPE_PCI" > /dev/null
    if [ $? -eq 0 ]; then
        gRetStr="$IFTYPE_PCI" 
        return 0
    fi

    echo "$hwinfo" | grep "$IFTYPE_USB" > /dev/null
    if [ $? -eq 0 ]; then
        gRetStr="$IFTYPE_USB"
        return 0
    fi

    Dbg3 "Not found the interface with $IFTYPE_USB or $IFTYPE_PCI"
    return 2
}

#
# Check process is parent
#
# param[in] $1: none
#
# return  Is parent, zero is returned.
#         Not parent, others is returned.
#
Common_iIsParent()
{
    local process=`ps -p $PPID | awk '{print $4}'| tail -1`
    #echo "process: $process"

    if [ "$process" = "sudo" ]; then
        return 0
    fi

    return 1
}

#
# To find the network interface
#
# param[in] $1: the string of network interface
# param[in] $2: IP address
# param[in] $3: Default gateway
# param[in] $4: Primary DNS
# param[in] $5: Secondary DNS
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Common_iSetIpRoute()
{
    local iface=$1
    local ip_addr=$2
    local def_gateway=$3
    local primary_dns=$4
    local secondary_dns=$5

    if [ -z $iface ] || [ -z $ip_addr ] || [ -z $def_gateway ] || [ -z $primary_dns ] || [ -z $secondary_dns ]; then
	    Dbg3 "IF/IP/GW/Primanry DNS/Secondary DNS is null ($iface / $ip_addr / $def_gateway / $primary_dns / $secondary_dns) ! "
        return 1
    fi

    local tmpfile=/tmp/setip.txt

    echo "ip link set $iface down" > $tmpfile
    echo "ip addr flush dev $iface" >> $tmpfile
    echo "ip -6 addr flush dev $iface" >> $tmpfile
    echo "ip link set $iface up" >> $tmpfile
    echo "ip addr add $ip_addr/255.255.255.0 dev $iface broadcast +" >> $tmpfile
    echo "ip route add default via $def_gateway dev $iface metric 101" >> $tmpfile
    echo "ip link set mtu 1500 dev $iface" >> $tmpfile

    local ubuntu_ver=`cat /etc/lsb-release | grep -w "DISTRIB_RELEASE" | cut -d'=' -f2 | cut -d'.' -f1`
    if [ $? -eq 0 ] && [ ! -z $ubuntu_ver ]; then
        if [ $ubuntu_ver -ge 22 ]; then
            Dbg3 "Ubuntu version is greater than or equal 22.04"
            echo "resolvectl -4 dns $iface $primary_dns $secondary_dns" >> $tmpfile
        else
            Dbg3 "Ubuntu version is less than 22.04"
            echo "systemd-resolve -4 --interface=$iface --set-dns=$primary_dns" >> $tmpfile
            echo "systemd-resolve -4 --interface=$iface --set-dns=$secondary_dns" >> $tmpfile
        fi
    fi

    FileDbg $tmpfile
    sh $tmpfile

    return 0
}


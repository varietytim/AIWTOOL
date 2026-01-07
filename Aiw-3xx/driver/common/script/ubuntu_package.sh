#!/bin/sh

#
# Install packages needed for AIW tool
#
# param[in]: none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Package_iInstall()
{
    local flag=0;
    local package_update=0;

    apt-get update

    packages="net-tools \
                openssh-server \
                minicom \
                vim \
                build-essential \
                libqmi-glib-dev \
                libqmi-utils \
                libmbim-utils \
                bzip2 \
                ethtool"

    #
    # Install kernel header if it's not exist
    #
    if [ ! -d "/lib/modules/$(uname -r)" ]; then
        packages="$packages linux-headers-$(uname -r)"
        Msg "Prepare to install kernel header."
    fi
    
    for i in $(echo $packages)
    do
        dpkg -s $i > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            [ $flag -eq 0 ] && Msg "Prepare some packages to install." && flag=1
            apt-get install $i
            if [ $? -ne 0 ]; then
                package_update=1
                break
            fi
        fi
    done

    local ubuntu_ver=`cat /etc/lsb-release | grep -w "DISTRIB_RELEASE" | cut -d'=' -f2 | cut -d'.' -f1`
    if [ $? -eq 0 ] && [ ! -z $ubuntu_ver ]; then
	if [ $ubuntu_ver -gt 22 ]; then
	    apt-get install systemd-resolved
	fi	
    fi
    
    if [ $package_update -eq 1 ]; then
        Msg "Failed to install package, and please check your internet connection."
        return 1
    fi

    return 0
}


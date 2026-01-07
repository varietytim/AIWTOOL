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
    #local flag=0;

    packages="net-tools \
                openssh-server \
                vim \
                build-essential"

    for i in $(echo $packages)
    do
        dpkg -s $i > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            #[ $flag -eq 0 ] && Msg "Prepare some packages to install." && flag=1
            apt-get install $i
        fi
    done

    return 0
}


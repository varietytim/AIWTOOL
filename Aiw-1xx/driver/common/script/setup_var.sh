#!/bin/sh

#
# To find the version
#
gVersionFile="$gTopdir/../version"

#
# The folders of source which we need to copy from
#
gSDir_Connect="$gTopdir/template/connect"

#
# The configuration
#
gUsrCfgdir="$gTopdir/driver/config"
gCfgFile="$gUsrCfgdir/user.cfg"

#
# Write the item to user configuration
#
# param[in] $1: overwrite:0 or append:1
# param[in] $2~$n: the string for each item.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Setup_iWriteUsrCfg()
{
    local action="$1"
    local item;

    shift
    for i in $(seq 1 $#)
    do
        #eval "echo \$$i"
        eval item="'${item}'\$$i!"
    done

    item=`echo "$item" | sed -e "s/!/\n/g"`

    if [ "$action" = 1 ]; then
        echo "$item" >> "$gCfgFile"
    else
        echo "$item" > "$gCfgFile"
    fi

    return $?
}

#
# Parser key and get value with user configuration
#
# param[in] $1: the string of key.
# param[out] gRetStr: the string of value.
#
# return  On success, zero is returned.
#         On error, others.
#
Setup_iUCGetValue()
{
    local key=$1

    if [ -z $key ]; then
        Msg "Argument is null"
        return 1
    fi

    if [ ! -e $gCfgFile ]; then
        Dbg "Not find the $gCfgFile!"
        return 2
    fi

    gRetStr=`grep -w "$key" $gCfgFile | cut -d'=' -f2 | sed -e 's/\"//g'`
    [ -z $gRetStr ] && return 3

    return 0
}

#
# Append file to user configuration 
#
# param[in] $1: the path to find file.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Setup_iAppendFileToUsrCfg()
{
    local file_path=$1

    if [ -z $file_path ] || [ ! -e $file_path ]; then
        return 1
    fi 

    cat "$file_path" |grep -v "#" >> $gCfgFile

    return $?
}

#
# Do clean action
#
# param[in] none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Setup_iClean()
{
    # Romove all configurations
    if [ -e $gUsrCfgdir ] && [ "$(ls -A $gUsrCfgdir)" ]; then
        Msg "Remove all user configurations"
        rm -rI $gUsrCfgdir/*
    fi

    return 0
}

#
# Parser key and get value with profile
#
# param[in] $1: the path to find profile file.
# param[in] $2: the string of key.
# param[out] gRetStr: the string of value.
#
# return  On success, zero is returned.
#         On error, others.
#
Setup_iPFGetValue()
{
    local profile=$1
    local key=$2

    if [ -z $profile ] || [ -z $key ]; then
        Msg "Argument is null"
        return 1
    fi

    if [ ! -e $profile ]; then
        Dbg "Not find the $profile!"
        return 2
    fi

    gRetStr=`grep -w "$key" $profile | cut -d'=' -f2 | sed -e 's/\"//g'`
    [ -z $gRetStr ] && return 3

    return 0
}

#
# Check module ID
#
# param[in] $1: the path to find profile file.
#
# return  To find the module, zero is returned.
#         Not find the module, others is returned.
#
Setup_iCheckHwModule()
{
    local file=$1
    local vendorId;
    local productId;

    if [ ! -e $file ]; then
        Dbg "The $file is not exist!"
        return 2
    fi

    vendorId=''
    productId=''
    Setup_iPFGetValue "$file" 'gPf_VendorID'
    [ $? -eq 0 ] && vendorId=$gRetStr
    Dbg "[PF] vendorId=$vendorId"

    Setup_iPFGetValue "$file" 'gPf_ProductID'
    [ $? -eq 0 ] && productId=$gRetStr
    Dbg "[PF] productId=$productId"

    if [ ! -z $vendorId ] && [ ! -z $productId ]; then
        Common_iCheckModuleID "$vendorId" "$productId"
        if [ $? -eq 0 ]; then
            Dbg "Find the $vendorId:$productId"
            return 0
        fi
    fi

    vendorId=''
    productId=''
    Setup_iPFGetValue "$file" 'gPf_VendorID2'
    [ $? -eq 0 ] && vendorId=$gRetStr
    Dbg "[PF] vendorId2=$vendorId"

    Setup_iPFGetValue "$file" 'gPf_ProductID2'
    [ $? -eq 0 ] && productId=$gRetStr
    Dbg "[PF] productId2=$productId"

    if [ ! -z $vendorId ] && [ ! -z $productId ]; then
        Common_iCheckModuleID "$vendorId" "$productId"
        if [ $? -eq 0 ]; then
            Dbg "Find the $vendorId:$productId"
            return 0
        fi
    fi

    Dbg "Not found the module"
    return 1
}

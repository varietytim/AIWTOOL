#!/bin/sh

#
# Prompt the user to input string
#
# param[in] $1: the string of prompt.
# param[in] $2: the string of max length.
# param[out] gRetStr: the string inputed from user.
#
# return  On success, zero is returned.
#         On error, others is returned.
#
Interact_iGetString()
{
    local prompt="$1"
    local maxlen="$2"
    local tmp;
    
    if [ -z "$prompt" ] || [ -z "$maxlen" ]; then
        return 1
    fi

    while :
    do
        read -p "$prompt" tmp
        if [ ${#tmp} -gt $maxlen ]; then
            Msg "The maximum length is $maxlen!"
            continue
        fi
        break
    done  

    gRetStr=$tmp

    return 0
}

#
# Prompt the user to select the item
#
# param[in] $1: the string of prompt.
# param[in] $2~$n: the string for each item.
# param[out] gRetStr: the string of item selected from user.
#
# return  On success, the number of item is returned.
#         On error, zero is returned.
#
Interact_iListItem()
{
    local prompt="$1"
    local total_arg=$#
    local total_item=$(( total_arg - 1 ))
    local ArgN=2;
    local item;
    local input;
    local i;

    while :
    do
        Msg "$prompt"
        for i in $(seq 1 $total_item)
        do
            eval "item"="\$$ArgN"
            Msg "$i) $item"
            ArgN=$(( ArgN + 1 ))
        done

        read -p "" input

        if [ ! -z "$input" ]; then
            if [ "$input" -ge 1 ] && [ $input -le $i ]; then
                ArgN=$(( input + 1 ))
                eval "gRetStr=\$$ArgN"
                break
            fi
        fi

        echo "The input is out of selection!"
        ArgN=2
    done

    return $input
}

#
# Prompt the user to select the item
#
# param[in] $1: the string of prompt.
# param[in] $2: the path to scan the directory.
# param[out] gRetStr: the string of directory selected from user.
#
# return  On success, the number of item is returned.
#         On error, zero is returned.
#
Interact_iListDir()
{
    local prompt="$1"
    local path="$2"
    local directory;
    local input;

    [ ! -e $path ] && return 0

    while :
    do
        n=1
        echo "$prompt"
        for directory in $(ls -c $path | sort); do
            eval "local item$n"="$directory"
            echo "$n) $directory"
            n=$(( n + 1 ))
        done

        read -p "" input

        if [ ! -z "$input" ]; then
            if [ "$input" -ge 1 ] && [ $input -lt $n ]; then
                eval "gRetStr=\$item$input"
                break
            fi
        fi
        echo "The input is out of selection!"
    done

    return $input
}


#
# title
#
# param[in]: none.
#
# return  On success, zero is returned.
#         On error, others is returned.
#

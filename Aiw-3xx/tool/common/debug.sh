#!/bin/sh

#
# Debug
#
gDebug=0


Dbg()
{
    [ $gDebug -ge 1 ] && echo "\033[34m$1\033[0m"
}

Dbg2()
{
    [ $gDebug -ge 2 ] && echo "\033[34m$1\033[0m"
}

Dbg3()
{
    [ $gDebug -ge 3 ] && echo "\033[34m$1\033[0m"
}

FileDbg()
{
    [ $gDebug -ge 2 ] && cat $1
}

Dbg_iGetDbgLevel()
{
    return $gDebug
}

Dbg_iParserLevel()
{
    #
    # Parser the format with 'debug=level_num'
    #
    local dbg_level=0
    local tmp=`echo "$1" | grep debug | cut -d'=' -f2`
    if [ ! -z $tmp ] && [ $tmp -ge 1 ] 2> /dev/null; then
        dbg_level=$tmp
    fi

    return $dbg_level
}
